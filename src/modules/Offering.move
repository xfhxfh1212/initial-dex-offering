address 0x99a287696c35e978c19249400c616c6a {
module Offering {
    use 0x1::STC::STC;
    use 0x1::Event;
    use 0x1::Errors;

    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Token;

    // todo: address need replace
    use 0xd800a4813e2f3ef20f9f541004dbd189::DummyToken::USDT;
    // todo: address need replace
    const OWNER_ADDRESS: address = @0x99a287696c35e978c19249400c616c6a;
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
    const EXCEED_PERSONAL_STC_STAKING_LIMIT : u64 = 100008;

    // IDO token pool
    struct Offering<TokenType: store> has key, store {
        // tokens for IDO
        tokens: Token::Token<TokenType>,
        // total token amount for IDO, never changed
        token_total_amount: u128,
        // usdt exchange rate, never changed
        usdt_rate: u128,
        // personal stc staking upper limit, never changed
        personal_stc_staking_limit: u128,
        // IDO state
        state: u8,
        // IDO owner address
        offering_addr: address,
        // stc staking total amount, never changed after OFFERING_UNSTAKING
        // used for calculating the personal percentage of tokens
        stc_staking_amount: u128,
        // amount of token offered 
        token_offering_amount: u128,
        // the version, plus one after updating
        version: u128,
        // create eventt
        offering_created_event: Event::EventHandle<OfferingCreatedEvent>,
        // update event
        offering_update_event: Event::EventHandle<OfferingUpdateEvent>,
    }

    // personal staking
    struct Staking<TokenType: store> has key, store {
        // current staking stc
        stc_staking: Token::Token<STC>,
        // personal stc staking total amount, never changed after OFFERING_UNSTAKING
        // used for calculating the personal percentage of tokens
        stc_staking_amount: u128,
        // flag for pay usdt
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
        // usdt exchange rate.
        usdt_rate: u128,
    }

    // emitted when offering update state.
    struct OfferingUpdateEvent has drop, store {
        // the version.
        version: u128,
        // offering state.
        state: u8,
        // total amount of current stc staking
        stc_staking_amount: u128,
        // total amount of token offered
        token_offering_amount: u128,
    }

    // emitted when staking or unstaking.
    struct TokenStakingEvent has drop, store {
        // the version.
        version: u128,
        // stc staking amount.
        stc_staking_amount: u128,
    }

    // emitted when exchange token.
    struct TokenExchangeEvent has drop, store {
        // the version.
        version: u128,
        // token exchange amount.
        token_exchange_amount: u128,
    }

    public fun emit_offering_update_event<TokenType: store>(offering: &mut Offering<TokenType>) {
        Event::emit_event(
            &mut offering.offering_update_event,
            OfferingUpdateEvent { 
                version: offering.version,
                state: offering.state,
                stc_staking_amount: offering.stc_staking_amount,
                token_offering_amount: offering.token_offering_amount,
            },
        );
    }

    // staking
    // stake STC for exchange token.
    public fun staking<TokenType: store>(account: &signer, stc_amount: u128) acquires Offering, Staking {
        let offering = borrow_global_mut<Offering<TokenType>>(OWNER_ADDRESS);
        // check state
        assert(offering.state == OFFERING_OPENING, Errors::invalid_state(STATE_ERROR));
        // check balance
        let signer_addr = Signer::address_of(account);
        let stc_balance = Account::balance<STC>(signer_addr);
        assert(stc_balance > stc_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        // move stc from balance to staking
        let stc_staking = Account::withdraw<STC>(account, stc_amount);
        // check resource exist
        let staking: &mut Staking<TokenType>;
        if (exists<Staking<TokenType>>(signer_addr)) {
            // personal stc upper limit
            staking = borrow_global_mut<Staking<TokenType>>(signer_addr);
            let stc_staking_amount = staking.stc_staking_amount + stc_amount;
            assert(stc_staking_amount <= offering.personal_stc_staking_limit, Errors::invalid_argument(EXCEED_PERSONAL_STC_STAKING_LIMIT));
            // deposit stc to staking
            Token::deposit(&mut staking.stc_staking, stc_staking);
            // add personal stc staking amount
            staking.stc_staking_amount = stc_staking_amount;
            // version + 1
            staking.version = staking.version + 1;
        } else {
            // personal stc upper limit
            assert(stc_amount <= offering.personal_stc_staking_limit, Errors::invalid_argument(EXCEED_PERSONAL_STC_STAKING_LIMIT));
            move_to<Staking<TokenType>>(account, Staking<TokenType> {
                stc_staking: stc_staking,
                stc_staking_amount: stc_amount,
                is_pay_off: false,
                version: 1u128,
                token_staking_event: Event::new_event_handle<TokenStakingEvent>(account),
                token_exchange_event: Event::new_event_handle<TokenExchangeEvent>(account),
            });
            staking = borrow_global_mut<Staking<TokenType>>(signer_addr);
        };
        // add total stc staking amount
        offering.stc_staking_amount = offering.stc_staking_amount + stc_amount;
        offering.version = offering.version + 1;
        // emit staking event
        Event::emit_event(
            &mut staking.token_staking_event,
            TokenStakingEvent {
                version: staking.version,
                stc_staking_amount: offering.stc_staking_amount,
            },
        );
        emit_offering_update_event<TokenType>(offering);
    }

    // unstaking
    // subtract amount of staking STC.
    public fun unstaking<TokenType: store>(account: &signer, stc_amount: u128) acquires Offering, Staking  {
        let offering = borrow_global_mut<Offering<TokenType>>(OWNER_ADDRESS);
        // check state
        assert(offering.state != OFFERING_PENDING, Errors::invalid_state(STATE_ERROR));
        // check staking amount
        let signer_addr = Signer::address_of(account);
        assert(exists<Staking<TokenType>>(signer_addr), Errors::invalid_state(STAKING_NOT_EXISTS));
        let staking = borrow_global_mut<Staking<TokenType>>(signer_addr);
        let staking_value = Token::value<STC>(&staking.stc_staking);
        assert(staking_value >= stc_amount, Errors::invalid_state(INSUFFICIENT_STAKING));
        // move stc from staking to balance
        let stc_unstaking = Token::withdraw<STC>(&mut staking.stc_staking, stc_amount);
        Account::deposit<STC>(signer_addr, stc_unstaking);
        // subtract stc staking amount
        if (offering.state == OFFERING_OPENING || offering.state == OFFERING_STAKING) {
            staking.stc_staking_amount = staking.stc_staking_amount - stc_amount;
            offering.stc_staking_amount = offering.stc_staking_amount - stc_amount;
        };
        staking.version = staking.version + 1;
        // emit unstaking event
        Event::emit_event(
            &mut staking.token_staking_event,
            TokenStakingEvent {
                version: staking.version,
                stc_staking_amount: offering.stc_staking_amount,
            },
        );
        // version + 1
        offering.version = offering.version + 1;
        emit_offering_update_event<TokenType>(offering);
    }

    // exchange token
    // exchange token by USDT, token max amount is caculated by stc_staking_amount.
    public fun exchange<TokenType: store>(account: &signer) acquires Staking, Offering {
        let user_address = Signer::address_of(account);
        assert(exists<Staking<TokenType>>(user_address), Errors::invalid_argument(STAKING_NOT_EXISTS));
        let staking_token = borrow_global_mut<Staking<TokenType>>(user_address);

        assert(exists<Offering<TokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        let pool = borrow_global_mut<Offering<TokenType>>(OWNER_ADDRESS);
        assert(pool.state == OFFERING_UNSTAKING, Errors::invalid_state(STATE_ERROR));

        // obtained token
        let obtained_tokens = mul_div(pool.token_total_amount, staking_token.stc_staking_amount, pool.stc_staking_amount);
        let amount = Token::value<TokenType>(&pool.tokens);
        assert(amount >= obtained_tokens, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        // USDT

        let need_pay_amount = mul_div(pool.usdt_rate, obtained_tokens, Token::scaling_factor<TokenType>());
        let usdt_balance = Account::balance<USDT>(user_address);
        assert(usdt_balance >= need_pay_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        // pay USDT for token
        let usdt_tokens = Account::withdraw<USDT>(account, need_pay_amount);
        Account::deposit(OWNER_ADDRESS, usdt_tokens);

        // claim tokens for user
        let claimed_tokens = Token::withdraw(&mut pool.tokens, obtained_tokens);
        pool.token_offering_amount = pool.token_offering_amount + Token::value<TokenType>(&claimed_tokens);
        // accept token
        let is_accept_token = Account::is_accepts_token<TokenType>(Signer::address_of(account));
        if (!is_accept_token) {
            Account::do_accept_token<TokenType>(account);
        };
        Account::deposit_to_self(account, claimed_tokens);
        emit_offering_update_event(pool);

        // unstaking STC
        let unstaking_amount = Token::value<STC>(&staking_token.stc_staking);
        let staking_tokens = Token::withdraw(&mut staking_token.stc_staking,  unstaking_amount);
        Account::deposit_to_self(account, staking_tokens);

        staking_token.is_pay_off = true;

        Event::emit_event<TokenExchangeEvent>(&mut staking_token.token_exchange_event, TokenExchangeEvent {
            // the version.
            version: staking_token.version,
            // token exchange amount.
            token_exchange_amount: obtained_tokens
        });
    }

    // destory resource
    fun destory_staking<TokenType: store>(user_address: address) acquires Staking {
        let staking_token = move_from<Staking<TokenType>>(user_address);
        let Staking<TokenType> {
            stc_staking,
            stc_staking_amount: _,
            is_pay_off: _,
            version: _,
            token_staking_event,
            token_exchange_event,
        } = staking_token;
        Token::destroy_zero(stc_staking);
        Event::destroy_handle(token_staking_event);
        Event::destroy_handle(token_exchange_event);
    }

    // create IDO project
    public fun create<TokenType: store>(account: &signer, token_amount: u128, usdt_rate: u128, personal_stc_staking_limit: u128, offering_addr: address) 
    acquires Offering {
        let owner_address = Signer::address_of(account);
        assert(owner_address == OWNER_ADDRESS, Errors::requires_capability(CAN_NOT_CHANGE_BY_CURRENT_USER));
        let token_balance = Account::balance<TokenType>(owner_address);
        assert(token_balance >= token_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        let tokens = Account::withdraw<TokenType>(account, token_amount);
        move_to<Offering<TokenType>>(account, Offering<TokenType> {
            tokens: tokens,
            usdt_rate: usdt_rate,
            personal_stc_staking_limit: personal_stc_staking_limit,
            state: OFFERING_PENDING,
            offering_addr: offering_addr,
            stc_staking_amount: 0,
            token_offering_amount: 0,
            token_total_amount: token_amount,
            version: 0,
            offering_created_event: Event::new_event_handle<OfferingCreatedEvent>(account),
            offering_update_event: Event::new_event_handle<OfferingUpdateEvent>(account) 
        });
        let offering = borrow_global_mut<Offering<TokenType>>(owner_address);
        Event::emit_event<OfferingCreatedEvent>(
            &mut offering.offering_created_event, 
            OfferingCreatedEvent {
                // token for offering.
                token_amount,
                // usdt exchange rate.
                usdt_rate,
            }
        );
    }

    // update state
    // PENDING/OPENING/STAKING reversible
    // UNSTAKING/CLOSED reversible
    public fun state_change<TokenType: store>(account: &signer, state: u8) acquires Offering {
        let owner_address = Signer::address_of(account);
        assert(owner_address == OWNER_ADDRESS, Errors::requires_capability(CAN_NOT_CHANGE_BY_CURRENT_USER));
        assert(state >= OFFERING_PENDING && state <= OFFERING_CLOSED, Errors::invalid_state(UNSUPPORT_STATE));
        assert(exists<Offering<TokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        let pool = borrow_global_mut<Offering<TokenType>>(owner_address);
        if (pool.state == state) {
            return
        };
        if (pool.state > OFFERING_STAKING && state < OFFERING_UNSTAKING) {
            ()
        };
        pool.state = state;
        pool.version = pool.version + 1;
        emit_offering_update_event<TokenType>(pool);
    }

    public fun personal_stc_staking<TokenType: store>(account_addr: address): u128 acquires Staking {
        let staking = borrow_global<Staking<TokenType>>(account_addr);
        Token::value<STC>(&staking.stc_staking)
    }

    public fun offering_tokens_value<TokenType: store>(): u128 acquires Offering {
        let offering = borrow_global<Offering<TokenType>>(OWNER_ADDRESS);
        Token::value<TokenType>(&offering.tokens)
    }

    public fun offering_stc_staking<TokenType: store>(): u128 acquires Offering {
        assert(exists<Offering<TokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        let offering = borrow_global<Offering<TokenType>>(OWNER_ADDRESS);
        *&offering.stc_staking_amount
    }

    public fun offering_state<TokenType: store>(): u8 acquires Offering {
        assert(exists<Offering<TokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        let offering = borrow_global<Offering<TokenType>>(OWNER_ADDRESS);
        *&offering.state
    }

      public fun mul_div(x: u128, y: u128, z: u128): u128 {
        if ( y  == z ) {
            return x
        };
        if ( x > z) {
            return x/z*y
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