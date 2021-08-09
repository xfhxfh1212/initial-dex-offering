address 0xd501465255d22d1751aae83651421198 {
module OfferingScript2 {
    use 0xd501465255d22d1751aae83651421198::Offering2;

    public(script) fun staking<TokenType: store>(account: signer, stc_amount: u128) {
        Offering2::staking<TokenType>(&account, stc_amount)
    }

    public(script) fun unstaking<TokenType: store>(account: signer, stc_amount: u128) {
        Offering2::unstaking<TokenType>(&account, stc_amount)
    }

    public(script) fun exchange<TokenType: store>(account: signer) {
        Offering2::exchange<TokenType>(&account)
    }

    public(script) fun create<TokenType: store>(account: signer, token_amount: u128, usdt_rate: u128, offering_addr: address) {
        Offering2::create<TokenType>(&account, token_amount, usdt_rate, offering_addr)
    }

    public(script) fun state_change<TokenType: store>(account: signer, state: u8) {
        Offering2::state_change<TokenType>(&account, state)
    }

}
}
