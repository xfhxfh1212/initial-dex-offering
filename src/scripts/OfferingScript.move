address 0x99a287696c35e978c19249400c616c6a {
module OfferingScript {
    use 0x99a287696c35e978c19249400c616c6a::Offering;

    public(script) fun staking<TokenType: store>(account: signer, stc_amount: u128) {
        Offering::staking<TokenType>(&account, stc_amount)
    }

    public(script) fun unstaking<TokenType: store>(account: signer, stc_amount: u128) {
        Offering::unstaking<TokenType>(&account, stc_amount)
    }

    public(script) fun exchange<TokenType: store>(account: signer) {
        Offering::exchange<TokenType>(&account)
    }

    public(script) fun create<TokenType: store>(account: signer, token_amount: u128, usdt_rate: u128, personal_stc_staking_limit: u128, offering_addr: address) {
        Offering::create<TokenType>(&account, token_amount, usdt_rate, personal_stc_staking_limit, offering_addr)
    }

    public(script) fun state_change<TokenType: store>(account: signer, state: u8) {
        Offering::state_change<TokenType>(&account, state)
    }

}
}
