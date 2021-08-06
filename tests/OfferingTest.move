address 0x200 {
module OfferingTest {
    use 0x1::STC::STC;
    use 0x1::Account;
    use 0x100::Offering;
    use 0x110::DummyToken::{USDT, DUMMY};
    use 0x200::TestHelper;

    const POOL_ADDRESS: address = @0x100;

    const OFFERING_ADDRESS: address = @0x201;
    const ADMIN_ADDRESS: address = @0x202;
    const USER1_ADDRESS: address = @0x203;
    const USER2_ADDRESS: address = @0x204;

    const MULTIPLE: u128 = 1000000000;

    // owner 
    #[test(admin = @0x202, user = @0x203, pool = @0x100, dummy = @0x110)]
    fun test_staking(admin: &signer, user: &signer, pool: &signer, dummy: &signer) {
        // mint 100 TOKEN to pool
        TestHelper::mint_token<DUMMY>(dummy, pool, 100u128);
        // create pool & change state to opening
        Offering::create<DUMMY>(pool, 100 * MULTIPLE, 1, OFFERING_ADDRESS);
        Offering::state_change<DUMMY>(pool, 2);
        // mint 20 STC to user
        TestHelper::mint_stc(admin, user, 20);
        // mint 100 USDT to user
        TestHelper::mint_token<USDT>(dummy, user, 100u128);
        // staking 10 stc
        Offering::staking<DUMMY>(user, 10);
        // assert
        let staking_value = Offering::personal_stc_staking<DUMMY>(USER1_ADDRESS);
        let stc_balance = Account::balance<STC>(USER1_ADDRESS);
        // staking = 10 STC
        assert(staking_value == 10 * MULTIPLE, 100);
        // balance = 10 STC
        assert(stc_balance == 10 * MULTIPLE, 101);
        
        // pool.tokens = 100 TOKEN
        let offering_tokens_value = Offering::offering_tokens_value<DUMMY>();
        assert(offering_tokens_value == 100 * MULTIPLE, 102);
        // pool.stc_staking_amount = 10 STC
        let offering_stc_staking = Offering::offering_stc_staking<DUMMY>();
        assert(offering_stc_staking == 10 * MULTIPLE, 103);
    }

}
}
