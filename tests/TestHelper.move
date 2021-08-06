address 0x200 {
module TestHelper {
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::STC;
    use 0x1::Timestamp;
    //    use 0x1::Debug;
    use 0x110::DummyToken;

    const PRECISION: u8 = 9;

    public fun init_stdlib(): signer {
        let stdlib = Account::create_genesis_account(@0x1);
        Timestamp::initialize( & stdlib, 1626356267u64);
        Token::register_token<STC::STC>( & stdlib, 9u8);
        stdlib  
    }

    public fun init_account_with_stc(account: &signer, amount: u128, stdlib: &signer) {
        let account_address = Signer::address_of(account);
        if (amount >0) {
            deposit_stc_to(account, amount, stdlib);
            let stc_balance = Account::balance<STC::STC>(account_address);
            assert(stc_balance == amount, 999);
        };
    }

    public fun deposit_stc_to(account: &signer, amount: u128, stdlib: &signer) {
        let is_accept_token = Account::is_accepts_token<STC::STC>(Signer::address_of(account));
        if (!is_accept_token) {
            Account::do_accept_token<STC::STC>(account);
        };
        let total_stc = Token::mint<STC::STC>(stdlib, amount);
        Account::deposit<STC::STC>(Signer::address_of(account), total_stc);
    }

    public fun mint_stc_to(amount: u128, stdlib: &signer): Token::Token<STC::STC> {
        Token::mint<STC::STC>(stdlib, amount)
    }


    public fun wrap_to_stc_amount(amount: u128): u128 {
        amount * pow_10(PRECISION)
    }

    public fun pow_10(exp: u8): u128 {
        pow(10, exp)
    }

    public fun pow(base: u64, exp: u8): u128 {
        let result_val = 1u128;
        let i = 0;
        while (i < exp) {
            result_val = result_val * (base as u128);
            i = i + 1;
        };
        result_val
    }

    // mint stc to account
    public fun mint_stc(account: &signer, amount: u128) {
        let std_signer = init_stdlib();
        // init_account_with_stc(admin, 0u128, &std_signer);
        let init_amount = wrap_to_stc_amount(amount);
        init_account_with_stc(account, init_amount, &std_signer);
    }

    // mint token to account 
    public fun mint_token<TokenType: store>(dummy: &signer, account: &signer, amount: u128) {
        // init token 
        let dummy_address = Signer::address_of(dummy);
        if (!Token::is_registered_in<TokenType>(dummy_address)) {
            DummyToken::initialize<TokenType>(dummy);
        };
        // mint token to account
        let account_address = Signer::address_of(account);
        let is_accept_token = Account::is_accepts_token<TokenType>(account_address);
        if (!is_accept_token) {
            Account::do_accept_token<TokenType>(account);
        };
        let mint_amount = amount * pow_10(DummyToken::precision());
        let token = DummyToken::mint<TokenType>(mint_amount);
        Account::deposit_to_self(account, token);
    }

    public fun init_account(pool: &signer, dummy: &signer, user: &signer) {
        Account::create_genesis_account(Signer::address_of(pool));
        Account::create_genesis_account(Signer::address_of(dummy));
        Account::create_genesis_account(Signer::address_of(user));
    }

}
}