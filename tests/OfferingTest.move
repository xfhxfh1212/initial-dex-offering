address 0x200 {
module OfferingTest {
    // use 0x1::Signer;
    use 0x1::STC::STC;
    use 0x100::Offering;
    use 0x110::DummyToken::{USDT, DummyToken};
    use 0x200::TestHelper;

    const POOL_ADDRESS: address = @0x100;
    const OFFERING_ADDRESS: address = @0x201;
    const ADMIN_ADDRESS: address = @0x202;
    const USER1_ADDRESS: address = @0x203;
    const USER2_ADDRESS: address = @0x204;

    const MULTIPLE: u128 = 1000000000;

    // owner 
    #[test(admin = ADMIN_ADDRESS, user = USER1_ADDRESS, pool = POOL_ADDRESS)]
    fun test_staking(admin: &signer, user: &signer, pool: &signer) {
        // mint 100 TOKEN to pool
        TestHelper::mint_token<DummyToken>(pool, 100);
        // create pool & change state to opening
        Offering::create<DummyToken>(pool, 100 * MULTIPLE, 1, OFFERING_ADDRESS);
        Offering::state_change<DummyToken>(pool, 2);
        // mint 20 STC to user
        TestHelper::mint_stc(admin, user, 20);
        // mint 100 USDT to user
        TestHelper::mint_token<USDT>(admin, user, 100);
        // staking 10 stc
        Offering::staking<DummyToken>(user, 10);
        // assert
        let staking = borrow_global<Staking<DummyToken>>(USER1_ADDRESS);
        let staking_value = Token::value<STC>(&staking.stc_staking);
        let stc_balance = Account::balance<STC>(USER1_ADDRESS);
        // staking = 10 STC
        assert(staking_value == 10 * MULTIPLE, 100);
        // balance = 10 STC
        assert(stc_balance == 10 * MULTIPLE, 101);
        
        // pool.tokens = 100 TOKEN
        let offering = borrow_global<Offering<DummyToken>>(POOL_ADDRESS);
        let offering_tokens_value = Token::value<DummyToken>(&offering.tokens);
        assert(offering_tokens_value == 100 * MULTIPLE, 102);
        // pool.stc_staking_amount = 10 STC
        assert(offering.stc_staking_amount == 10 * MULTIPLE, 103);
    }

}
}
