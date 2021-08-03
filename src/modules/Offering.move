address {{address}} {
module Offering {
    use 0x1::STC;
    use 0x1::Event;
    
    const OFFERING_PENDING : u8 = 1;
    const OFFERING_OPENING : u8 = 2;
    const OFFERING_STAKING : u8 = 3;
    const OFFERING_UNSTAKING : u8 = 4;
    const OFFERING_CLOSED : u8 = 5;
    
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
        // the counter.
        counter: u128,
        // create event.
        offering_created_event: Event::new_event_handle<OfferingCreatedEvent>(signer),
        // state update event.
        offering_state_update_event: Event::new_event_handle<OfferingStateUpdateEvent>(signer),
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
    // 用户领取代币数 obtained_tokens = Staking::stc_staking_amount / Offering::stc_staking_amount * Offering::tokens::value
    // 用户需支付 usdt = obtained_tokens * Offering::usdt_rate
    // Offering::state == UNSTAKING
    // 1. account::balance::usdt -> Offering::balance::usdt usdt支付
    // 2. Staking::stc_staking -> balance::stc 解质押
    // 3. Offering::tokens -> balance 发币
    public fun exchange<TokenType: store>(account: &signer) {
        
    }

    // 创建项目
    // 项目方打款 -> balance 接受空投开关
    // 初始化Offering，balance.<token> -> Offering::tokens<token>
    public fun create<TokenType: store>(account: &signer, token_amount: u128, usdt_rate: u128, offering_addr: address, total_staking: u128) {

    }

    // 项目状态修改
    // 待开放(无法操作)、开放中(可加可减)、质押中(可减) 可逆
    // 解押中(可减可兑换)、已结束(可解押) 可逆
    public fun state_change<TokenType: store>(account: &signer, state: u8) {
        
    }

}
}