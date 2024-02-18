import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract } from "ethers";

describe("SafeLock Strategy", function () {
  let pennypot: Contract;
  // let safeLock: Contract;
  let token: Contract;
  let owner: any, addr1: any;
  let myPot: any;
  before(async function () {
    // Assuming Pennypot contract is already deployed and its address is known
    const pennyAddress = ethers.getAddress(
      "0xc4a1D0485C0C7e465c56aE8d951bdCd861f40Cd5"
    );
    const strategyAddress = ethers.getAddress(
      "0xfFbB148591467a7d154fba6157F3602F01C81eEa"
    );
    const Pennypot = await ethers.getContractFactory("PennyPot");
    pennypot = Pennypot.attach(pennyAddress) as Contract;

    // Deploy a mock ERC20 token for testing
    const Token = await ethers.getContractFactory("TestERC20");
    token = (await Token.deploy()) as any;

    // Deploy a SafeLock pot
    // The create function deploys a new SafeLock instance for user
    const createTx = await pennypot.create(strategyAddress, [token.target]);
    await createTx.wait();
    //get pot address by strategy
    const pots = (await pennypot.getPotsByStrategies(strategyAddress)) as any;
    //current pot index
    myPot = pots[pots.length - 1];
    [owner, addr1] = await ethers.getSigners();
  });

  it("Should allow user's opt-in savings for a token", async function () {
    const lockPeriod = 60 * 60 * 24; // 1 day in seconds
    await pennypot.optIn(myPot, token.target, lockPeriod);

    const _pot = await ethers.getContractFactory("SafeLock");
    const potContract = _pot.attach(myPot) as Contract;
    const [isActive] = await potContract.getTokenDetails(token.target);
    console.log(isActive);
    expect(isActive).to.be.true;
  });
});
