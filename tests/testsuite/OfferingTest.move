//! account: dummy, 0x4ef1e60bad4c5b9bbccf0de115e1f5a0, 20000000000 0x1::STC::STC
//! sender: dummy
address dummy_address = {{dummy}};
script {
    use 0x1::Token;
    use 0x4ef1e60bad4c5b9bbccf0de115e1f5a0::DummyToken::{Self, DUMMY, USDT};

    fun init_dummy(sender: signer) {
        DummyToken::initialize<DUMMY>(&sender);
        assert(Token::is_registered_in<DUMMY>(@dummy_address), 1000);

        DummyToken::initialize<USDT>(&sender);
        assert(Token::is_registered_in<USDT>(@dummy_address), 1001);
    }
}
// check: "Keep(EXECUTED)"

//! new-transaction
//! account: pool, 0x64c66296d98d6ab08579b14487157e05, 20000000000 0x1::STC::STC
//! sender: pool
address pool_address = {{pool}};
script {
    use 0x1::Account;
    use 0x1::STC::STC;
    use 0x64c66296d98d6ab08579b14487157e05::Offering;
    use 0x4ef1e60bad4c5b9bbccf0de115e1f5a0::DummyToken::{Self, USDT, DUMMY};
    const MULTIPLE: u128 = 1000000000;

    fun test_create(sender: signer) {
        // mint 100 DUMMY to pool
        DummyToken::mint_token<DUMMY>(&sender, 100 * MULTIPLE);
        let balance = Account::balance<DUMMY>(@pool_address);
        assert(100 * MULTIPLE == balance, 1100);
        // accept usdt
        Account::do_accept_token<USDT>(&sender);

        // create pool 
        Offering::create<STC, USDT, DUMMY>(&sender, 100 * MULTIPLE, 1 * MULTIPLE, 20 * MULTIPLE, @pool_address);
        let offering_tokens_value = Offering::offering_tokens_value<STC, USDT, DUMMY>();
        assert(offering_tokens_value == 100 * MULTIPLE, 1101);
        assert(Offering::offering_state<STC, USDT, DUMMY>() == 1, 1102);
        // change state to opening
        Offering::state_change<STC, USDT, DUMMY>(&sender, 2);
        assert(Offering::offering_state<STC, USDT, DUMMY>() == 2, 1102);
    }
}
// check: "Keep(EXECUTED)"

//! new-transaction
//! account: user, 100000000000000 0x1::STC::STC
//! sender: user
address user_address = {{user}};
script {
    use 0x1::Account;
    use 0x1::STC::STC;
    use 0x64c66296d98d6ab08579b14487157e05::Offering;
    use 0x4ef1e60bad4c5b9bbccf0de115e1f5a0::DummyToken::{Self, USDT, DUMMY};
    const MULTIPLE: u128 = 1000000000;

    fun test_staking(sender: signer) {
        // mint 100 USDT to user
        DummyToken::mint_token<USDT>(&sender, 100 * MULTIPLE);
        let balance = Account::balance<USDT>(@user_address);
        assert(100 * MULTIPLE == balance, 1200);
        
        // staking 20 stc
        Offering::staking<STC, USDT, DUMMY>(&sender, 20 * MULTIPLE);
        // assert
        let staking_value = Offering::personal_staking_token_amount<STC, USDT, DUMMY>(@user_address);
        // staking = 20 STC
        assert(staking_value == 20 * MULTIPLE, 1202);
        // pool.tokens = 100 TOKEN
        let offering_tokens_value = Offering::offering_tokens_value<STC, USDT, DUMMY>();
        assert(offering_tokens_value == 100 * MULTIPLE, 1203);
        // pool.stc_staking_amount = 20 STC
        let offering_stc_staking = Offering::offering_staking_token_amount<STC, USDT, DUMMY>();
        assert(offering_stc_staking == 20 * MULTIPLE, 1204);
    }
}
// check: "Keep(EXECUTED)"

//! new-transaction
//! sender: pool
address pool_address = {{pool}};
script {
    use 0x1::STC::STC;
    use 0x64c66296d98d6ab08579b14487157e05::Offering;
    use 0x4ef1e60bad4c5b9bbccf0de115e1f5a0::DummyToken::{USDT, DUMMY};
    const MULTIPLE: u128 = 1000000000;

    fun update_state_to_staking(sender: signer) {
        // change state to staking
        Offering::state_change<STC, USDT, DUMMY>(&sender, 3);
        assert(Offering::offering_state<STC, USDT, DUMMY>() == 3, 1300);
    }
}
// check: "Keep(EXECUTED)"

//! new-transaction
//! sender: user
address user_address = {{user}};
script {
    use 0x1::STC::STC;
    use 0x64c66296d98d6ab08579b14487157e05::Offering;
    use 0x4ef1e60bad4c5b9bbccf0de115e1f5a0::DummyToken::{USDT, DUMMY};
    const MULTIPLE: u128 = 1000000000;

    fun test_unstaking(sender: signer) {
        // unstaking 10 stc
        Offering::unstaking<STC, USDT, DUMMY>(&sender, 10 * MULTIPLE);
        let staking_value = Offering::personal_staking_token_amount<STC, USDT, DUMMY>(@user_address);
        // staking = 10 STC
        assert(staking_value == 10 * MULTIPLE, 1300);
        // pool.stc_staking_amount = 10 STC
        let offering_stc_staking = Offering::offering_staking_token_amount<STC, USDT, DUMMY>();
        assert(offering_stc_staking == 10 * MULTIPLE, 1301);
    }
}
// check: "Keep(EXECUTED)"

//! new-transaction
//! sender: pool
address pool_address = {{pool}};
script {
    use 0x1::STC::STC;
    use 0x64c66296d98d6ab08579b14487157e05::Offering;
    use 0x4ef1e60bad4c5b9bbccf0de115e1f5a0::DummyToken::{USDT, DUMMY};
    const MULTIPLE: u128 = 1000000000;

    fun update_state_to_unstaking(sender: signer) {
        // change state to unstaking
        Offering::state_change<STC, USDT, DUMMY>(&sender, 4);
        assert(Offering::offering_state<STC, USDT, DUMMY>() == 4, 1400);
    }
}
// check: "Keep(EXECUTED)"

//! new-transaction
//! sender: user
address user_address = {{user}};
address pool_address = {{pool}};
script {
    use 0x1::Account;
    use 0x1::STC::STC;
    use 0x64c66296d98d6ab08579b14487157e05::Offering;
    use 0x4ef1e60bad4c5b9bbccf0de115e1f5a0::DummyToken::{USDT, DUMMY};
    const MULTIPLE: u128 = 1000000000;

    fun test_exchange(sender: signer) {
        // unstaking 10 stc
        Offering::unstaking<STC, USDT, DUMMY>(&sender, 10 * MULTIPLE);
        let staking_value = Offering::personal_staking_token_amount<STC, USDT, DUMMY>(@user_address);
        // staking = 10 STC
        assert(staking_value == 0, 1300);
        // pool.stc_staking_amount = 10 STC
        let offering_stc_staking = Offering::offering_staking_token_amount<STC, USDT, DUMMY>();
        assert(offering_stc_staking == 10 * MULTIPLE, 1301);

        // exchange 100 DUMMY
        Offering::exchange<STC, USDT, DUMMY>(&sender);
        // staking = 0 STC 
        let staking_value = Offering::personal_staking_token_amount<STC, USDT, DUMMY>(@user_address);
        assert(staking_value == 0, 1500);
        // user.stc >= 20
        let user_stc_balance = Account::balance<STC>(@user_address);
        assert(user_stc_balance >= 20 * MULTIPLE, 1501);
        // user.dummy = 100
        let user_dummy_balance = Account::balance<DUMMY>(@user_address);
        assert(user_dummy_balance == 100 * MULTIPLE, 1502);
        // user.usdt = 0 
        let user_usdt_balance = Account::balance<USDT>(@user_address);
        assert(user_usdt_balance == 0, 1503);
        // pool.staking = 0
        let offering_tokens_value = Offering::offering_tokens_value<STC, USDT, DUMMY>();
        assert(offering_tokens_value == 0, 1504);
        // pool.usdt = 100
        let pool_usdt_balance = Account::balance<USDT>(@pool_address);
        assert(pool_usdt_balance == 100 * MULTIPLE, 1505);
        // pool.dummy = 0
        let pool_dummy_balance = Account::balance<DUMMY>(@pool_address);
        assert(pool_dummy_balance == 0, 1506);

    }
}
