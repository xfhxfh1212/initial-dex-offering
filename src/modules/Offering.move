address 0xeE337598EAEd6b2317C863aAf3870948 {
module Offering {
    use 0x1::STC::STC;
    use 0x1::USDT::USDT;
    use 0x1::Event;
    use 0x1::Errors;

    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Token;

    const OWNER_ADDRESS : address = 0xeE337598EAEd6b2317C863aAf3870948;
    
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

    // IDO token pool
    struct Offering<TokenType: store> has key, store {
        // tokens for IDO
        tokens: Token::Token<TokenType>,
        // total token amount for IDO, never changed
        token_total_amount: u128,
        // usdt exchange rate, never changed
        usdt_rate: u128,
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
        // create event
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

    public fun emit_offering_update_event<TokenType: store>(offering: &mut Offering<TokenType>) acquires Offering {
        Event::emit_event(
            offering.offering_update_event,
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
    public(script) fun staking<TokenType: store>(account: &signer, stc_amount: u128) {
        let offering = borrow_global_mut<Offering<TokenType>>(OWNER_ADDRESS);
        // check state
        assert(offering.state == OFFERING_OPENING, Errors::invalid_state(STATE_ERROR));
        // check balance
        let signer_addr = Signer::address_of(account);
        let stc_balance = Account::balance<STC>(signer_addr);
        assert(stc_balance > stc_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        // move stc from balance to staking
        let stc_staking = Account::withdraw<STC>(account, token_amount);
        // check resource exist
        let staking;
        if (exist<Staking>(signer_addr)) {
            // deposit stc to staking
            staking = borrow_global_mut<Staking>(signer_addr);
            Token::deposit(&mut staking.stc_staking, stc_staking);
            // add personal stc staking amount
            staking.stc_staking_amount = staking.stc_staking_amount + token_amount;
            // version + 1
            staking.version = staking.version + 1;
        } else {
            staking = Staking {
                stc_staking: stc_staking,
                stc_staking_amount: stc_amount,
                version: 1u128,
                token_staking_event: Event::new_event_handle<TokenStakingEvent>(signer),
                token_exchange_event: Event::new_event_handle<TokenExchangeEvent>(signer),
            };
            move_to(account, staking);
        };
        // add total stc staking amount
        offering.stc_staking_amount = offering.stc_staking_amount + token_amount;
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
    public(script) fun unstaking<TokenType: store>(account: &signer, stc_amount: u128) {
        let offering = borrow_global_mut<Offering<TokenType>>(OWNER_ADDRESS); 
        // check state
        assert(offering.state != OFFERING_PENDING, Errors::invalid_state(STATE_ERROR));
        // check staking amount
        let signer_addr = Signer::address_of(account);
        assert(exist<Staking>(signer_addr), Errors::invalid_state(STAKING_NOT_EXISTS));
        let staking = borrow_global_mut<Staking>(signer_addr);
        assert(staking >= stc_amount, Errors::invalid_state(INSUFFICIENT_STAKING));
        // move stc from staking to balance
        let stc_unstaking = Token::withdraw<STC>(staking.tokens, stc_amount);
        Account::deposit<STC>(account, stc_unstaking);
        // subtract stc staking amount
        if (offering.state == OFFERING_OPENING || offering.state == OFFERING_STAKING) {
            staking.stc_staking_amount = staking.stc_staking_amount - stc_amount;
            offering.stc_staking_amount = offering.stc_staking_amount - stc_amount;
        };
        // version + 1
        staking.version = staking.version + 1;
        offering.version = offering.version + 1;
        // emit unstaking event
        Event::emit_event(
            &mut staking.stc_staking_event,
            StcStakingEvent {
                version: staking.version,
                stc_staking_amount: offering.stc_staking_amount,
            },
        );
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
        let obtained_tokens = pool.token_total_amount * staking_token.stc_staking_amount / pool.stc_staking_amount;
        let amount = Token::value<TokenType>(&pool.tokens);
        assert(amount >= obtained_tokens, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        // USDT
        let need_pay_amount = pool.usdt_rate * obtained_tokens;
        let usdt_balance = Account::balance<USDT>(user_address);
        assert(usdt_balance >= need_pay_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        // pay USDT for token
        let usdt_tokens = Account::withdraw<USDT>(account, need_pay_amount);
        Account::deposit(OWNER_ADDRESS, usdt_tokens);

        // claim tokens for user
        let claimed_tokens = Token::withdraw(&mut pool.tokens, obtained_tokens);
        Account::deposit_to_self(account, claimed_tokens);
        pool.token_offering_amount = pool.token_offering_amount + Token::value<TokenType>(&claimed_tokens);
        emit_offering_update_event(pool);

        // unstaking STC
        let staking_tokens = Token::withdraw(&mut staking_token.stc_staking, Token::value<STC>(&staking_token.stc_staking));
        Account::deposit_to_self(account, staking_tokens);

        Event::emit_event<TokenExchangeEvent>(&mut staking_token.token_exchange_event, TokenExchangeEvent {
            // the version.
            version: staking_token.version,
            // token exchange amount.
            token_exchange_amount: obtained_tokens
        });

        // destory resource
        let Staking<TokenType> {
            stc_staking: _,
            stc_staking_amount: _,
            version: _,
            token_staking_event: _,
            token_exchange_event: _,
        } = staking_token;
    }

    // create IDO project
    public fun create<TokenType: store>(account: &signer, token_amount: u128, usdt_rate: u128, offering_addr: address) {
        let owner_address = Signer::address_of(account);
        assert(owner_address == OWNER_ADDRESS, Errors::requires_capability(CAN_NOT_CHANGE_BY_CURRENT_USER));
        let token_balance = Account::balance<TokenType>(owner_address);
        assert(token_balance >= token_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        let tokens = Account::withdraw<TokenType>(account, token_amount);
        let offering_create_event_handler = Event::new_event_handle<OfferingCreatedEvent>(account);
        move_to<Offering<TokenType>>(account, Offering<TokenType> {
            tokens: tokens,
            usdt_rate: usdt_rate,
            state: OFFERING_PENDING,
            offering_addr: offering_addr,
            stc_staking_amount: 0,
            token_offering_amount: 0,
            token_total_amount: token_amount,
            version: 0,
            offering_created_event: offering_create_event_handler,
            offering_update_event: Event::new_event_handle<OfferingUpdateEvent>(account) 
        });
        Event::emit_event<OfferingCreatedEvent>(&mut offering_create_event_handler, OfferingCreatedEvent {
            // token for offering.
            token_amount,
            // usdt exchange rate.
            usdt_rate,
        });
    }

    // update state
    // PENDING/OPENING/STAKING reversible
    // UNSTAKING/CLOSED reversible
    public fun state_change<TokenType: store>(account: &signer, state: u8) acquires Offering {
        let owner_address = Signer::address_of(account);
        assert(owner_address == OWNER_ADDRESS, Errors::requires_capability(CAN_NOT_CHANGE_BY_CURRENT_USER));
        assert(state > OFFERING_PENDING && state < OFFERING_CLOSED, Errors::invalid_state(UNSUPPORT_STATE));
        assert(exists<Offering<TokenType>>(OWNER_ADDRESS), Errors::invalid_argument(OFFERING_NOT_EXISTS));
        let pool = borrow_global_mut<Offering<TokenType>>(owner_address);
        
        if (pool.state > OFFERING_STAKING && state < OFFERING_UNSTAKING) {
            return ;
        };
        pool.version = pool.version + 1;
        emit_offering_update_event<TokenType>(pool);
    }

}
}