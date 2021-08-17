address 0x64c66296d98d6ab08579b14487157e05 {
module Offering {
    use 0x1::Event;
    use 0x1::Errors;

    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Token;

    // todo: address need replace
    const OWNER_ADDRESS: address = @0x64c66296d98d6ab08579b14487157e05;
    // waiting for open, forbid any operation
    const OFFERING_PENDING: u8 = 1;
    // opening for staking or unstaking
    const OFFERING_OPENING: u8 = 2;
    // forbid adding staking, permit unstaking 
    const OFFERING_STAKING: u8 = 3;
    // permit unstaking or exchanging token
    const OFFERING_UNSTAKING: u8 = 4;
    // IDO closed, only permit unstaking
    const OFFERING_CLOSED: u8 = 5;

    // errors
    const STATE_ERROR: u64 = 100001;
    const UNSUPPORT_STATE : u64 = 100002;
    const INSUFFICIENT_BALANCE: u64 = 100003;
    const INSUFFICIENT_STAKING: u64 = 100004;
    const STAKING_NOT_EXISTS : u64 = 100005;
    const OFFERING_NOT_EXISTS : u64 = 100006;
    const CAN_NOT_CHANGE_BY_CURRENT_USER : u64 = 100007;
    const EXCEED_PERSONAL_STAKING_AMOUNT_LIMIT : u64 = 100008;

    // IDO token pool
    struct Offering<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store> has key, store {
        // tokens for IDO
        offering_tokens: Token::Token<OfferingTokenType>,
        // total token amount for IDO, never changed
        offering_token_total_amount: u128,
        // exchange rate, never changed
        exchange_rate: u128,
        // personal staking token upper limit, never changed
        personal_staking_token_amount_limit: u128,
        // IDO state
        state: u8,
        // IDO owner address
        offering_addr: address,
        // staking token total amount, never changed after OFFERING_UNSTAKING
        // used for calculating the personal percentage of tokens
        staking_token_amount: u128,
        // amount of token offered 
        offering_token_exchanged_amount: u128,
        // the version, plus one after updating
        version: u128,
        // create eventt
        offering_created_event: Event::EventHandle<OfferingCreatedEvent>,
        // update event
        offering_update_event: Event::EventHandle<OfferingUpdateEvent>,
    }

    // personal staking
    struct Staking<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store> has key, store {
        // current staking tokens
        staking_tokens: Token::Token<StakingTokenType>,
        // personal staking token total amount, never changed after OFFERING_UNSTAKING
        // used for calculating the personal percentage of tokens
        staking_token_amount: u128,
        // flag for pay token
        is_pay_off: bool,
        // the version, plus one after updating
        version: u128,
        // staking_event
        token_staking_event: Event::EventHandle<TokenStakingEvent>,
        // exchange_event
        token_exchange_event: Event::EventHandle<TokenExchangeEvent>,
    }

    // emitted when offering created.
    struct OfferingCreatedEvent has drop, store {
        // token for offering.
        token_amount: u128,
        // exchange rate.
        exchange_rate: u128,
    }

    // emitted when offering update state.
    struct OfferingUpdateEvent has drop, store {
        // the version.
        version: u128,
        // offering state.
        state: u8,
        // total amount of current staking token
        staking_token_amount: u128,
        // total amount of token offered
        offering_token_exchanged_amount: u128,
    }

    // emitted when staking or unstaking.
    struct TokenStakingEvent has drop, store {
        // the version.
        version: u128,
        // staking token amount.
        staking_token_amount: u128,
    }

    // emitted when exchange token.
    struct TokenExchangeEvent has drop, store {
        // the version.
        version: u128,
        // token exchange amount.
        token_exchange_amount: u128,
    }


    // create IDO project
    public fun create<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>
    (account: &signer, token_amount: u128, exchange_rate: u128, personal_staking_token_amount_limit: u128, offering_addr: address) 
    acquires Offering {
        let owner_address = Signer::address_of(account);
        assert(owner_address == OWNER_ADDRESS, Errors::requires_capability(CAN_NOT_CHANGE_BY_CURRENT_USER));
        let token_balance = Account::balance<OfferingTokenType>(owner_address);
        assert(token_balance >= token_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        let offering_tokens = Account::withdraw<OfferingTokenType>(account, token_amount);
        move_to<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(account, 
        Offering<StakingTokenType, PaidTokenType, OfferingTokenType> {
            offering_tokens: offering_tokens,
            exchange_rate: exchange_rate,
            personal_staking_token_amount_limit: personal_staking_token_amount_limit,
            state: OFFERING_PENDING,
            offering_addr: offering_addr,
            staking_token_amount: 0,
            offering_token_exchanged_amount: 0,
            offering_token_total_amount: token_amount,
            version: 0,
            offering_created_event: Event::new_event_handle<OfferingCreatedEvent>(account),
            offering_update_event: Event::new_event_handle<OfferingUpdateEvent>(account) 
        });
        let offering = borrow_global_mut<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(owner_address);
        Event::emit_event<OfferingCreatedEvent>(
            &mut offering.offering_created_event, 
            OfferingCreatedEvent {
                // token for offering.
                token_amount,
                // exchange rate.
                exchange_rate,
            }
        );
    }

    // update state
    // PENDING/OPENING/STAKING reversible
    // UNSTAKING/CLOSED reversible
    public fun state_change<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>(account: &signer, state: u8) 
    acquires Offering {
        let owner_address = Signer::address_of(account);
        assert(owner_address == OWNER_ADDRESS, Errors::requires_capability(CAN_NOT_CHANGE_BY_CURRENT_USER));
        assert(state >= OFFERING_PENDING && state <= OFFERING_CLOSED, Errors::invalid_state(UNSUPPORT_STATE));
        assert(exists<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        let pool = borrow_global_mut<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(owner_address);
        if (pool.state == state) {
            return
        };
        if (pool.state > OFFERING_STAKING && state < OFFERING_UNSTAKING) {
            ()
        };
        pool.state = state;
        pool.version = pool.version + 1;
        emit_offering_update_event<StakingTokenType, PaidTokenType, OfferingTokenType>(pool);
    }

    // staking
    // stake StakingToken for obtain OfferingToken.
    public fun staking<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>(account: &signer, staking_token_amount: u128) 
    acquires Offering, Staking {
        // check resource
        assert(exists<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        // check state
        let pool = borrow_global_mut<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS);
        assert(pool.state == OFFERING_OPENING, Errors::invalid_state(STATE_ERROR));
        // check balance
        let signer_addr = Signer::address_of(account);
        let staking_token_balance = Account::balance<StakingTokenType>(signer_addr);
        assert(staking_token_balance > staking_token_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        // withdraw staking token from balance
        let staking_tokens = Account::withdraw<StakingTokenType>(account, staking_token_amount);
        // check resource exist
        let staking: &mut Staking<StakingTokenType, PaidTokenType, OfferingTokenType>;
        if (exists<Staking<StakingTokenType, PaidTokenType, OfferingTokenType>>(signer_addr)) {
            // personal staking token upper limit
            staking = borrow_global_mut<Staking<StakingTokenType, PaidTokenType, OfferingTokenType>>(signer_addr);
            let staking_token_amount = staking.staking_token_amount + staking_token_amount;
            assert(staking_token_amount <= pool.personal_staking_token_amount_limit, Errors::invalid_argument(EXCEED_PERSONAL_STAKING_AMOUNT_LIMIT));
            // deposit staking token from staking
            Token::deposit(&mut staking.staking_tokens, staking_tokens);
            // add personal staking token amount
            staking.staking_token_amount = staking_token_amount;
            // version + 1
            staking.version = staking.version + 1;
        } else {
            // personal staking token upper limit
            assert(staking_token_amount <= pool.personal_staking_token_amount_limit, Errors::invalid_argument(EXCEED_PERSONAL_STAKING_AMOUNT_LIMIT));
            move_to<Staking<StakingTokenType, PaidTokenType, OfferingTokenType>>(account, 
            Staking<StakingTokenType, PaidTokenType, OfferingTokenType> {
                staking_tokens: staking_tokens,
                staking_token_amount: staking_token_amount,
                is_pay_off: false,
                version: 1u128,
                token_staking_event: Event::new_event_handle<TokenStakingEvent>(account),
                token_exchange_event: Event::new_event_handle<TokenExchangeEvent>(account),
            });
            staking = borrow_global_mut<Staking<StakingTokenType, PaidTokenType, OfferingTokenType>>(signer_addr);
        };
        // add total staking token amount
        pool.staking_token_amount = pool.staking_token_amount + staking_token_amount;
        pool.version = pool.version + 1;
        // emit staking event
        Event::emit_event(
            &mut staking.token_staking_event,
            TokenStakingEvent {
                version: staking.version,
                staking_token_amount: pool.staking_token_amount,
            },
        );
        emit_offering_update_event<StakingTokenType, PaidTokenType, OfferingTokenType>(pool);
    }

    // unstaking
    // subtract amount of staking token.
    public fun unstaking<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>(account: &signer, staking_token_amount: u128) 
    acquires Offering, Staking  {
        // check resource
        assert(exists<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        // check state
        let pool = borrow_global_mut<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS);
        assert(pool.state != OFFERING_PENDING, Errors::invalid_state(STATE_ERROR));
        // check staking amount
        let signer_addr = Signer::address_of(account);
        assert(exists<Staking<StakingTokenType, PaidTokenType, OfferingTokenType>>(signer_addr), Errors::invalid_state(STAKING_NOT_EXISTS));
        let staking = borrow_global_mut<Staking<StakingTokenType, PaidTokenType, OfferingTokenType>>(signer_addr);
        let staking_value = Token::value<StakingTokenType>(&staking.staking_tokens);
        assert(staking_value >= staking_token_amount, Errors::invalid_state(INSUFFICIENT_STAKING));
        // move staking token from staking to balance
        let unstaking_tokens = Token::withdraw<StakingTokenType>(&mut staking.staking_tokens, staking_token_amount);
        Account::deposit<StakingTokenType>(signer_addr, unstaking_tokens);
        // subtract staking token amount
        if (pool.state == OFFERING_OPENING || pool.state == OFFERING_STAKING) {
            staking.staking_token_amount = staking.staking_token_amount - staking_token_amount;
            pool.staking_token_amount = pool.staking_token_amount - staking_token_amount;
        };
        staking.version = staking.version + 1;
        // emit unstaking event
        Event::emit_event(
            &mut staking.token_staking_event,
            TokenStakingEvent {
                version: staking.version,
                staking_token_amount: pool.staking_token_amount,
            },
        );
        // version + 1
        pool.version = pool.version + 1;
        emit_offering_update_event<StakingTokenType, PaidTokenType, OfferingTokenType>(pool);
    }

    // exchange token
    // exchange token, token max amount is caculated by staking_token_amount.
    public fun exchange<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>(account: &signer) 
    acquires Staking, Offering {
        // check resource
        let user_address = Signer::address_of(account);
        assert(exists<Staking<StakingTokenType, PaidTokenType, OfferingTokenType>>(user_address), Errors::invalid_argument(STAKING_NOT_EXISTS));
        assert(exists<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        // check state
        let pool = borrow_global_mut<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS);
        assert(pool.state == OFFERING_UNSTAKING, Errors::invalid_state(STATE_ERROR));

        // obtained token
        let staking_token = borrow_global_mut<Staking<StakingTokenType, PaidTokenType, OfferingTokenType>>(user_address);
        let obtained_tokens = mul_div(pool.offering_token_total_amount, staking_token.staking_token_amount, pool.staking_token_amount);
        let amount = Token::value<OfferingTokenType>(&pool.offering_tokens);
        assert(amount >= obtained_tokens, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        // pay token
        let need_pay_amount = mul_div(pool.exchange_rate, obtained_tokens, Token::scaling_factor<OfferingTokenType>());
        let paid_token_balance = Account::balance<PaidTokenType>(user_address);
        assert(paid_token_balance >= need_pay_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        let paid_tokens = Account::withdraw<PaidTokenType>(account, need_pay_amount);
        Account::deposit(OWNER_ADDRESS, paid_tokens);

        // claim tokens for user
        let claimed_tokens = Token::withdraw(&mut pool.offering_tokens, obtained_tokens);
        pool.offering_token_exchanged_amount = pool.offering_token_exchanged_amount + Token::value<OfferingTokenType>(&claimed_tokens);
        // accept token
        let is_accept_token = Account::is_accepts_token<OfferingTokenType>(Signer::address_of(account));
        if (!is_accept_token) {
            Account::do_accept_token<OfferingTokenType>(account);
        };
        Account::deposit_to_self(account, claimed_tokens);
        emit_offering_update_event(pool);

        // unstaking StakingToken
        let unstaking_amount = Token::value<StakingTokenType>(&staking_token.staking_tokens);
        if (unstaking_amount > 0u128) {
            let staking_tokens = Token::withdraw(&mut staking_token.staking_tokens, unstaking_amount);
            Account::deposit_to_self(account, staking_tokens);
        };
        staking_token.is_pay_off = true;

        Event::emit_event<TokenExchangeEvent>(&mut staking_token.token_exchange_event, TokenExchangeEvent {
            // the version.
            version: staking_token.version,
            // token exchange amount.
            token_exchange_amount: obtained_tokens
        });
    }

    // destory resource
    public fun destory_offering<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>(account: &signer) 
    acquires Offering {
        withdraw_offering_tokens<StakingTokenType, PaidTokenType, OfferingTokenType>(account);
        let owner_address = Signer::address_of(account);
        let offering = move_from<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(owner_address);
        let Offering<StakingTokenType, PaidTokenType, OfferingTokenType> {
            offering_tokens,
            exchange_rate: _,
            personal_staking_token_amount_limit: _,
            state: _,
            offering_addr: _,
            staking_token_amount: _,
            offering_token_exchanged_amount: _,
            offering_token_total_amount: _,
            version: _,
            offering_created_event,
            offering_update_event,
        } = offering;
        Token::destroy_zero(offering_tokens);
        Event::destroy_handle(offering_created_event);
        Event::destroy_handle(offering_update_event);
    }

    // withdraw remain tokens when Offering closed
    public fun withdraw_offering_tokens<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>(account: &signer) 
    acquires Offering {
        let owner_address = Signer::address_of(account);
        assert(owner_address == OWNER_ADDRESS, Errors::requires_capability(CAN_NOT_CHANGE_BY_CURRENT_USER));
        assert(exists<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        let pool = borrow_global_mut<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS);
        assert(pool.state == OFFERING_CLOSED, Errors::invalid_state(STATE_ERROR));
        let remain_amount = Token::value<OfferingTokenType>(&pool.offering_tokens);
        let remain_tokens = Token::withdraw<OfferingTokenType>(&mut pool.offering_tokens, remain_amount);
        Account::deposit_to_self<OfferingTokenType>(account, remain_tokens);
        emit_offering_update_event(pool);
    }

    // emit offering_update_event
    fun emit_offering_update_event<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>
    (offering: &mut Offering<StakingTokenType, PaidTokenType, OfferingTokenType>) {
        Event::emit_event(
            &mut offering.offering_update_event,
            OfferingUpdateEvent { 
                version: offering.version,
                state: offering.state,
                staking_token_amount: offering.staking_token_amount,
                offering_token_exchanged_amount: offering.offering_token_exchanged_amount,
            },
        );
    }

    public fun personal_staking_token_amount<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>(account_addr: address): u128 
    acquires Staking {
        let staking = borrow_global<Staking<StakingTokenType, PaidTokenType, OfferingTokenType>>(account_addr);
        Token::value<StakingTokenType>(&staking.staking_tokens)
    }

    public fun offering_tokens_value<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>(): u128 
    acquires Offering {
        let offering = borrow_global<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS);
        Token::value<OfferingTokenType>(&offering.offering_tokens)
    }

    public fun offering_staking_token_amount<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>(): u128 
    acquires Offering {
        assert(exists<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        let offering = borrow_global<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS);
        *&offering.staking_token_amount
    }

    public fun offering_state<StakingTokenType: store, PaidTokenType: store, OfferingTokenType: store>(): u8 
    acquires Offering {
        assert(exists<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        let offering = borrow_global<Offering<StakingTokenType, PaidTokenType, OfferingTokenType>>(OWNER_ADDRESS);
        *&offering.state
    }

    public fun mul_div(x: u128, y: u128, z: u128): u128 {
        if (y == z) {
            return x
        };
        if (x == z) {
            return y
        };
        let a = x / z;
        let b = x % z;
        //x = a * z + b;
        let c = y / z;
        let d = y % z;
        //y = c * z + d;
        a * c * z + a * d + b * c + b * d / z
    }

}
}