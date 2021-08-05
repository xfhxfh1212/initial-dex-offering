address 0x200 {
module OfferingTest {
    // use 0x1::Signer;
    // use 0x1::Debug;
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
        // mint 100 token to pool
        TestHelper::mint_token<DummyToken>(pool, 100);
        // create pool & change state to opening
        Offering::create<DummyToken>(pool, 100 * MULTIPLE, 1, OFFERING_ADDRESS);
        Offering::state_change<DummyToken>(pool, 2);
        // mint 20 stc to user
        TestHelper::mint_stc(admin, user, 20);
        TestHelper::mint_token<USDT>(admin, user, 100);
        // staking 10 stc
        Offering::staking<DummyToken>(user, 10);
        // log
        let offering = borrow_global_mut<Offering<DummyToken>>(POOL_ADDRESS);
        Debug::print<Offering<DummyToken>>(offering);
    }


}
}
