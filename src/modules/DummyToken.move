address 0x110 {
module DummyToken {
    use 0x1::Account;
    use 0x1::Token;

    struct USDT has copy, drop, store {}
    struct DUMMY has copy, drop, store {}

    const PRECISION: u8 = 9;

    struct SharedMintCapability<TokenType: store> has key, store {
        cap: Token::MintCapability<TokenType>,
    }

    struct SharedBurnCapability<TokenType: store> has key, store {
        cap: Token::BurnCapability<TokenType>,
    }

    public fun initialize<TokenType: store>(account:&signer) {
        Token::register_token<TokenType>(account, PRECISION);
        Account::do_accept_token<TokenType>(account);
        let mint_cap = Token::remove_mint_capability<TokenType>(account);
        move_to(account, SharedMintCapability<TokenType> { cap: mint_cap });
        let burn_cap = Token::remove_burn_capability<TokenType>(account);
        move_to(account, SharedBurnCapability<TokenType> { cap: burn_cap });
    }

    public fun mint<TokenType:store >(amount: u128): Token::Token<TokenType>
    acquires SharedMintCapability {
        let cap = borrow_global<SharedMintCapability<TokenType>>(token_address<TokenType>());
        Token::mint_with_capability<TokenType>(
        & cap.cap,
        amount
        )
    }

    public fun token_address<TokenType: store>(): address {
        Token::token_address<TokenType>()
    }

    public fun precision(): u8 {
        PRECISION
    }
}
}
