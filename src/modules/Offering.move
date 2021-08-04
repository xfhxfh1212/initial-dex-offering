address 0x111111111 {
module Offering {
    use 0x1::STC;
    use 0x1::Event;
    use 0x1::Signer;
    
    const OFFERING_PENDING : u8 = 1;
    const OFFERING_OPENING : u8 = 2;
    const OFFERING_STAKING : u8 = 3;
    const OFFERING_UNSTAKING : u8 = 4;
    const OFFERING_CLOSED : u8 = 5;

    // errors
    const OFFERING_PROJECT_NOT_EXISTS : u64 = 100001;
    const CAN_NOT_CHANGE_BY_CURRENT_USER : u64 = 100002;
    const UNSUPPORT_STATE : u64 = 100003;
    const INSUFFICIENT_BALANCE : u64 = 100004;
    const UNSUPPORT_OPERATION_BY_STATE : u64 = 100005;
    const STAKING_NOT_FOUND : u64 = 100006;

    // 打新项目
    struct Offering<TokenType: store> has key store {
        // 总打新代币
        tokens: Token::Token<TokenType>,
        // u兑换率
        usdt_rate: u128,
        // 项目状态：待开放(无法操作)、开放中(可加可减)、质押中(可减)、解押中(可减可兑换)、已结束(可解押)
        state: u8,
        // 项目方地址
        offering_addr: address,
        // stc总质押量，解押后不变，用于计算代币分配
        stc_staking_amount: u128,
        // 已发放代币总量
        token_offering_amount: u128,
        // token总量
        token_total_amount: u128,
        // the counter.
        counter: u128,
        // create event.
        offering_created_event: Event::new_event_handle<OfferingCreatedEvent>(signer),
        // state update event.
        offering_state_update_event: Event::new_event_handle<OfferingStateUpdateEvent>(signer)
    }

    // 用户质押
    struct Staking<TokenType: store> has key store {
        // 当前质押stc
        stc_staking: Token::Token<STC::STC>,
        // 用户总质押stc，解押后不变，用于计算用户兑换代币数
        stc_staking_amount: u128
        // the counter.
        counter: u128,
        // staking_event.
        stc_staking_event: Event::new_event_handle<StcStakingEvent>(signer),
        // exchange_event.
        token_exchange_event: Event::new_event_handle<TokenExchangeEvent>(signer),
    }

    // emitted when offering created.
    struct OfferingCreatedEvent has drop, store {
        // token for offering.
        token_amount: u128,
        // usdt exchange rate.
        usdt_rate: u128,
    }

    // emitted when offering update state.
    struct OfferingStateUpdateEvent has drop, store {
        // the counter.
        counter: u128,
        // offering state.
        state: u8,
    }

    // emitted when staking or unstaking.
    struct StcStakingEvent has drop, store {
        // the counter.
        counter: u128,
        // stc staking amount.
        stc_staking_amount: u128,
    }

    // emitted when exchange token.
    struct TokenExchangeEvent has drop, store {
        // the counter.
        counter: u128,
        // token exchange amount.
        token_exchange_amount: u128,
    }

    // 质押
    // Offering::state == OPENING
    // balance::stc -> Staking::stc_staking
    // Staking::stc_staking_amount + stc_amount
    // Offering::stc_staking_amount + stc_amount
    public fun staking<TokenType: store>(account: &signer, stc_amount: u128) {

    }

    // 解押
    // Offering::state == OPENING || STAKING || UNSTAKING || CLOSED
    // Staking::stc_staking -> account::balance::stc
    // OPENING || STAKING Staking::stc_staking_amount - stc_amount
    // OPENING || STAKING Offering::stc_staking_amount - stc_amount
    public fun unstaking<TokenType: store>(account: &signer, stc_amount: u128) {

    }

    // 领取
    // 用户领取代币数 obtained_tokens = Staking::stc_staking_amount / Offering::stc_staking_amount * Offering::token_total_amount
    // 用户需支付 usdt = obtained_tokens * Offering::usdt_rate
    // Offering::state == OFFERING_UNSTAKING
    // 1. account::balance::usdt -> Offering::balance::usdt usdt支付
    // 2. Staking::stc_staking -> balance::stc 解质押
    // 3. Offering::tokens -> balance 发币
    public fun exchange<TokenType: store>(account: &signer) {
        let user_address = Signer::address_of(account);
        let staking_token = borrow_global_mut<Staking<TokenType>>(user_address);
        assert(staking_token, invalid_argument(STAKING_NOT_FOUND));

        let pool = borrow_global<Offering<TokenType>>(0x111111111);
        assert(pool.state == OFFERING_UNSTAKING, Errors::invalid_state(UNSUPPORT_OPERATION_BY_STATE));

        // 分发代币数量
        let obtained_tokens = pool.token_total_amount * staking_token.stc_staking_amount / pool.stc_staking_amount;
        let amount = Token::value<TokenType>(&pool.tokens);
        assert(amount >= obtained_tokens, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        // 需支付金额
        let need_pay_amount = pool.usdt_rate * obtained_tokens;
        let usdt_balance = Account::balance<TokenType::USDT>(user_address);
        assert(usdt_balance >= need_pay_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        // 扣用户usdt转给合约
        let usdt_tokens = Account::withdraw<TokenType::USDT>(account, need_pay_amount);
        Account::deposit(0x111111111, usdt_tokens);

        // 扣合约分发币转给用户
        let claimed_tokens = Token::withdraw(&mut pool.tokens, obtained_tokens);
        Account::deposit_to_self(account, claimed_tokens);
        pool.token_offering_amount = pool.token_offering_amount + claimed_tokens;

        // 解押所有stc转给用户
        let staking_tokens = Token::withdraw(&mut staking_token.stc_staking, Token::value<TokenType>(&staking_token.stc_staking));
        Account::deposit_to_self(account, staking_tokens);

        Event::emit_event<TokenExchangeEvent>(&mut account.offering_created_event, TokenExchangeEvent {
            // the counter.
            counter: staking_token.counter,
            // token exchange amount.
            token_exchange_amount: obtained_tokens
        });

        // 销毁resource
        let Staking<TokenType> {
            /// 当前质押stc
            stc_staking: _,
            // 用户总质押stc，解押后不变，用于计算用户兑换代币数
            stc_staking_amount: _
            // the counter.
            counter: _,
            // staking_event.
            stc_staking_event: _,
            // exchange_event.
            token_exchange_event: _
        } = staking_token
    }

    // 创建项目
    // 项目方打款 -> balance 接受空投开关
    // 初始化Offering，balance.<token> -> Offering::tokens<token>
    public fun create<TokenType: store>(account: &signer, token_amount: u128, usdt_rate: u128, offering_addr: address) {
        let owner_address = Signer::address_of(account);
        assert(owner_address == 0x111111111, Errors::requires_capability(CAN_NOT_CHANGE_BY_CURRENT_USER));
        let token_balance = Account::balance<TokenType>(owner_address);
        assert(token_balance >= token_amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        let tokens = Account::withdraw<TokenType>(account, token_amount);
        move_to<Offering<TokenType>>(account, Offering<TokenType> {
            // 总打新代币
            tokens: tokens,
            // u兑换率
            usdt_rate: usdt_rate,
            // 项目状态：待开放(无法操作)、开放中(可加可减)、质押中(可减)、解押中(可减可兑换)、已结束(可解押)
            state: OFFERING_PENDING,
            // 项目方地址
            offering_addr: offering_addr,
            // stc总质押量，解押后不变，用于计算代币分配
            stc_staking_amount: 0,
            // 已发放代币总量
            token_offering_amount: 0,
            token_total_amount: token_amount,
            counter: 0,
            // create_event 
            offering_created_event: Event::new_event_handle<OfferingCreatedEvent>(account),
            // state_update_event
            offering_state_update_event:  Event::new_event_handle<OfferingStateUpdateEvent>(account)
        })
        Event::emit_event<OfferingCreatedEvent>(&mut account.offering_created_event, OfferingCreatedEvent {
            // token for offering.
            token_amount,
            // usdt exchange rate.
            usdt_rate
        });
    }

    // 项目状态修改
    // 待开放(无法操作)、开放中(可加可减)、质押中(可减) 可逆
    // 解押中(可减可兑换)、已结束(可解押) 可逆
    public fun state_change<TokenType: store>(account: &signer, state: u8) acquires Offering<TokenType> {
        let owner_address = Signer::address_of(account);
        assert(owner_address == 0x111111111, Errors::requires_capability(CAN_NOT_CHANGE_BY_CURRENT_USER));
        assert(state > OFFERING_PENDING && state < OFFERING_CLOSED, Errors::invalid_state(UNSUPPORT_STATE))
        let pool = borrow_global_mut<Offering<TokenType>>(owner_address);
        assert(pool, Errors::invalid_argument(OFFERING_PROJECT_NOT_EXISTS));
        if (pool.state > OFFERING_STAKING && state < OFFERING_UNSTAKING) {
            return
        }
        pool.counter = pool.counter + 1;
        Event::emit_event<OfferingStateUpdateEvent>(&mut account.offering_created_event, OfferingStateUpdateEvent {
            // the counter.
            counter: pool.counter,
            // offering state.
            state: pool.state,
        });
        
    }
    }

}
}