address 0x99a287696c35e978c19249400c616c6a {
module DummyToken {
    use 0x1::Account;
    use 0x1::Token;
    use 0x1::Signer;

    struct STC has copy, drop, store {}
    struct USDT has copy, drop, store {}
    struct DUMMY has copy, drop, store {}
    struct BTC has copy, drop, store {}
    struct ETH has copy, drop, store {}
    struct DOGE has copy, drop, store {}
    struct XRP has copy, drop, store {}
    struct BCH has copy, drop, store {}
    struct LTC has copy, drop, store {}
    struct TRX has copy, drop, store {}
    struct ARI has copy, drop, store {}
    struct GEM has copy, drop, store {}
    struct TAU has copy, drop, store {}

    const PRECISION: u8 = 9;

    struct SharedMintCapability<TokenType: store> has key, store {
        cap: Token::MintCapability<TokenType>,
    }

    struct SharedBurnCapability<TokenType> has key {
        cap: Token::BurnCapability<TokenType>,
    }

    public(script) fun initialize<TokenType: store>(account: signer) {
        Token::register_token<TokenType>(&account, PRECISION);
        Account::do_accept_token<TokenType>(&account);

        let burn_cap = Token::remove_burn_capability<TokenType>(&account);
        move_to(&account, SharedBurnCapability<TokenType> { cap: burn_cap });

        let mint_cap = Token::remove_mint_capability<TokenType>(&account);
        move_to(&account, SharedMintCapability<TokenType> { cap: mint_cap });
    }

    public(script) fun mint_token<TokenType: store>(account: signer, amount: u128) acquires SharedMintCapability {
        let is_accept_token = Account::is_accepts_token<TokenType>(Signer::address_of(&account));
        if (!is_accept_token) {
            Account::do_accept_token<TokenType>(&account);
        };
        let token = mint<TokenType>(amount);
        Account::deposit_to_self(&account, token);
    }

    /// Burn the given token.
    public fun burn<TokenType: store>(token: Token::Token<TokenType>) acquires SharedBurnCapability{
        let cap = borrow_global<SharedBurnCapability<TokenType>>(token_address<TokenType>());
        Token::burn_with_capability(&cap.cap, token);
    }

    public fun mint<TokenType: store>(amount: u128): Token::Token<TokenType> acquires SharedMintCapability {
        let cap = borrow_global<SharedMintCapability<TokenType>>(token_address<TokenType>());
        Token::mint_with_capability<TokenType>(&cap.cap, amount)
    }

    public fun token_address<TokenType: store>(): address {
        Token::token_address<TokenType>()
    }

    public fun precision(): u8 {
        PRECISION
    }
}
}
