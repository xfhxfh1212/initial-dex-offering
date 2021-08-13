address 0x4ef1e60bad4c5b9bbccf0de115e1f5a0 {
module DummyTokenScript {
    use 0x4ef1e60bad4c5b9bbccf0de115e1f5a0::DummyToken;

    public(script) fun initialize<TokenType: store>(account: signer) {
        DummyToken::initialize<TokenType>(&account);
    }

    public(script) fun mint_token<TokenType: store>(account: signer, amount: u128) {
        DummyToken::mint_token<TokenType>(&account, amount);
    }

}
}
