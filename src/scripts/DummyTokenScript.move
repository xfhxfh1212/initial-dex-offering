address 0xd800a4813e2f3ef20f9f541004dbd189 {
module DummyTokenScript {
    use 0xd800a4813e2f3ef20f9f541004dbd189::DummyToken;

    public(script) fun initialize<TokenType: store>(account: signer) {
        DummyToken::initialize<TokenType>(&account);
    }

    public(script) fun mint_token<TokenType: store>(account: signer, amount: u128) {
        DummyToken::mint_token<TokenType>(&account, amount);
    }

}
}
