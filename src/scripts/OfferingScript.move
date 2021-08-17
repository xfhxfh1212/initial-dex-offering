address 0x64c66296d98d6ab08579b14487157e05 {
module OfferingScript {
    use 0x64c66296d98d6ab08579b14487157e05::Offering;

    public(script) fun staking<StakingTokenType: store, PayTokenType: store, OfferingTokenType: store>(account: signer, stc_amount: u128) {
        Offering::staking<StakingTokenType, PayTokenType, OfferingTokenType>(&account, stc_amount)
    }

    public(script) fun unstaking<StakingTokenType: store, PayTokenType: store, OfferingTokenType: store>(account: signer, stc_amount: u128) {
        Offering::unstaking<StakingTokenType, PayTokenType, OfferingTokenType>(&account, stc_amount)
    }

    public(script) fun exchange<StakingTokenType: store, PayTokenType: store, OfferingTokenType: store>(account: signer) {
        Offering::exchange<StakingTokenType, PayTokenType, OfferingTokenType>(&account)
    }

    public(script) fun create<StakingTokenType: store, PayTokenType: store, OfferingTokenType: store>
    (account: signer, token_amount: u128, usdt_rate: u128, personal_stc_staking_limit: u128, offering_addr: address) {
        Offering::create<StakingTokenType, PayTokenType, OfferingTokenType>(&account, token_amount, usdt_rate, personal_stc_staking_limit, offering_addr)
    }

    public(script) fun state_change<StakingTokenType: store, PayTokenType: store, OfferingTokenType: store>(account: signer, state: u8) {
        Offering::state_change<StakingTokenType, PayTokenType, OfferingTokenType>(&account, state)
    }

    public(script) fun withdraw_offering_tokens<StakingTokenType: store, PayTokenType: store, OfferingTokenType: store>(account: signer) {
        Offering::withdraw_offering_tokens<StakingTokenType, PayTokenType, OfferingTokenType>(&account)
    }

    public(script) fun destory_offering<StakingTokenType: store, PayTokenType: store, OfferingTokenType: store>(account: signer) {
        Offering::destory_offering<StakingTokenType, PayTokenType, OfferingTokenType>(&account)
    }
}
}
