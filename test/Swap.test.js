const {
  getUnnamedAccounts,
  ethers, deployments,
} = require('hardhat')
const { BigNumber } = require('ethers')
const chai = require('chai')
const expect = chai.expect
chai.use(require('chai-as-promised'))

describe('ESwap', function () {
  let accountA
  let accountB
  let MockERC20A
  let MockERC20B
  let MockERC721A
  let MockERC721B
  let MockERC1155A
  let MockERC1155B

  let te, owner
  var fee1 = ethers.utils.parseEther('1.1')
  var fee2 = ethers.utils.parseEther('1.2')

  beforeEach(async function () {
    await deployments.fixture(['mocks'])

    // Create Two Accounts
    const unnamed = await getUnnamedAccounts()
    accountA = await ethers.getSigner(unnamed[0])
    accountB = await ethers.getSigner(unnamed[1])
    expect(await ethers.provider.getBalance(accountA.address)).to.eq(ethers.utils.parseEther('10000'))
    expect(await ethers.provider.getBalance(accountB.address)).to.eq(ethers.utils.parseEther('10000'))

    // Create Two ERC20 Tokens
    MockERC20A = await (await ethers.getContractFactory('MockERC20', accountA)).deploy()
    MockERC20B = await (await ethers.getContractFactory('MockERC20', accountB)).deploy()
    await MockERC20A.deployed()
    await MockERC20B.deployed()

    // Create Two ERC721 Tokens
    MockERC721A = await (await ethers.getContractFactory('MockHero')).deploy()
    MockERC721B = await (await ethers.getContractFactory('MockHero')).deploy()
    await MockERC721A.deployed()
    await MockERC721B.deployed()

    // Create Two ERC1155 Tokens
    MockERC1155A = await (await ethers.getContractFactory('MockERC1155')).deploy('https://exampleA.org')
    MockERC1155B = await (await ethers.getContractFactory('MockERC1155')).deploy('https://exampleB.org')
    await MockERC1155A.deployed()
    await MockERC1155B.deployed()

    const ESwap = await ethers.getContractFactory('ESwap')
    te = await ESwap.deploy(fee1, fee2)
    te.deployed()
    owner = await te.owner()
  })

  it('Should keep equal', async function () {
    let start_bl = await ethers.provider.getBalance(owner)
    let offer

    function initSwap () {
      return te.connect(accountA).create([
        accountA.address, 0,
        [[MockERC721A.address, 0, 2], [MockERC1155A.address, 66, 6]],
         [[MockERC20A.address, ethers.utils.parseEther('6.0')]],
        0],
        [
          accountB.address, ethers.utils.parseEther('29.0'),
          [[MockERC721B.address, 0, 3], [MockERC1155B.address, 88, 8]],
          [[MockERC20B.address, ethers.utils.parseEther('8.0')]], 0],
        { value: ethers.utils.parseEther('20.0') })
    }

    const acceptSwap = (id = 1) => {
      return te.connect(accountB).accept(
        id, { value: ethers.utils.parseEther('30.2') },
      )
    }

    // A initiating contract, when ERC721 is not Mint and Approve, should fail
    await expect(initSwap()).to.be.rejectedWith('ERC721: invalid token ID')
    await (await MockERC721A.connect(accountA).mint(accountA.address, 3)).wait()
    await expect(initSwap()).to.be.rejectedWith('ERC721: caller is not token owner nor approved')
    await (await MockERC721A.connect(accountA).setApprovalForAll(te.address, true)).wait()

    // A initiating contract, when ERC1155 is not Mint and Approve, should fail
    await expect(initSwap()).to.be.rejectedWith('ERC1155: caller is not token owner nor approved')
    await (await MockERC1155A.connect(accountA).setApprovalForAll(te.address, true)).wait()
    await expect(initSwap()).to.be.rejectedWith('ERC1155: insufficient balance for transfer')
    await (await MockERC1155A.connect(accountA).mint(accountA.address, 6, 66)).wait()

    // A initiating contract, when ERC20 is not Mint and Approve, should fail
    await expect(initSwap()).to.be.rejectedWith('ERC20: insufficient allowance')
    await (await MockERC20A.connect(accountA).approve(te.address, ethers.utils.parseEther('6.0'))).wait()
    await expect(initSwap()).to.be.rejectedWith('ERC20: transfer amount exceeds balance')
    await (await MockERC20A.mint(accountA.address, ethers.utils.parseEther('6.0'))).wait()

    // A initiating contract, after Mint and Approve, should success
    await (await initSwap()).wait()
    expect(await te._swapsCounter()).to.eq(1)
    offer = await te._swaps(1)

    // Contract Offer Value Test
    expect(offer['initiator']['addr']).to.eq(accountA.address)
    expect(offer['initiator']['native']).to.eq(ethers.utils.parseEther('18.9'))
    expect(offer['initiator']['nfts']).to.eql([[MockERC721A.address, BigNumber.from(0), BigNumber.from(2)], [MockERC1155A.address, BigNumber.from(66), BigNumber.from(6)]])
    expect(offer['initiator']['coins']).to.eql([[MockERC20A.address, ethers.utils.parseEther('6.0')]])
    // expect(offer['target']['addr']).to.eq(accountB.address)
    expect(offer['target']['native']).to.eq(ethers.utils.parseEther('29.0'))
    expect(offer['target']['nfts']).to.eql([[MockERC721B.address, BigNumber.from(0), BigNumber.from(3)], [MockERC1155B.address, BigNumber.from(88), BigNumber.from(8)]])
    expect(offer['target']['coins']).to.eql([[MockERC20B.address, ethers.utils.parseEther('8.0')]])

    // B accepts contracts, when ERC721 is not Mint and Approve, should fail
    await expect(acceptSwap()).to.be.rejectedWith('ERC721: invalid token ID')
    await (await MockERC721B.connect(accountB).mint(accountB.address, 3)).wait()
    await expect(acceptSwap()).to.be.rejectedWith('ERC721: caller is not token owner nor approved')
    await (await MockERC721B.connect(accountB).setApprovalForAll(te.address, true)).wait()

    // B accepts contracts, when ERC1155 is not Mint and Approve, should fail
    await expect(acceptSwap()).to.be.rejectedWith('ERC1155: caller is not token owner nor approved')
    await (await MockERC1155B.connect(accountB).setApprovalForAll(te.address, true)).wait()
    await expect(acceptSwap()).to.be.rejectedWith('ERC1155: insufficient balance for transfer')
    await (await MockERC1155B.connect(accountB).mint(accountB.address, 8, 88)).wait()

    // B accepts contracts, when ERC20 is not Mint and Approve, should fail
    await expect(acceptSwap()).to.be.rejectedWith('ERC20: insufficient allowance')
    await (await MockERC20B.connect(accountB).approve(te.address, ethers.utils.parseEther('8.0'))).wait()
    await expect(acceptSwap()).to.be.rejectedWith('ERC20: transfer amount exceeds balance')
    await (await MockERC20B.mint(accountB.address, ethers.utils.parseEther('8.0'))).wait()

    // B accepts the contract, after Mint and Approve, should success
    const initBalance0 = await ethers.provider.getBalance(accountA.address)
    const initBalance1 = await ethers.provider.getBalance(accountB.address)

    const rec = await (await acceptSwap()).wait()

    // Native, ERC20, ERC721, ERC1155 balance test after contract completion
    // expect(await ethers.provider.getBalance(accountA.address)).to.eq(initBalance0.add(ethers.utils.parseEther('29.0')))
    // expect(await ethers.provider.getBalance(accountB.address)).to.eq(initBalance1.sub(ethers.utils.parseEther('30.0')).add(ethers.utils.parseEther('20.0')).sub(rec.cumulativeGasUsed.mul(rec.effectiveGasPrice)))
    expect(await MockERC20A.balanceOf(accountB.address)).to.eq(ethers.utils.parseEther('6.0'))
    expect(await MockERC20B.balanceOf(accountA.address)).to.eq(ethers.utils.parseEther('8.0'))
    expect(await MockERC721A.ownerOf(2)).to.eq(accountB.address)
    expect(await MockERC721B.ownerOf(3)).to.eq(accountA.address)
    expect(await MockERC1155A.balanceOf(accountB.address, 6)).to.eq(66)
    expect(await MockERC1155B.balanceOf(accountA.address, 8)).to.eq(88)

    offer = await te._swaps(1)
    expect(offer.status).to.eq(3)

    // Contract owner account increases by 1 unit of fee
    const end_bl = await ethers.provider.getBalance(owner)
    // expect(end_bl).to.eq(start_bl.add(fee2))
  })

  it('Should cancel success', async function () {

    let start_bl = await ethers.provider.getBalance(owner)

    let offer

    async function initSwap () {
      await (await MockERC721A.connect(accountA).mint(accountA.address, 3)).wait()
      await (await MockERC721A.connect(accountA).setApprovalForAll(te.address, true)).wait()
      await (await MockERC1155A.connect(accountA).setApprovalForAll(te.address, true)).wait()
      await (await MockERC1155A.connect(accountA).mint(accountA.address, 6, 66)).wait()
      await (await MockERC20A.connect(accountA).approve(te.address, ethers.utils.parseEther('6.0'))).wait()
      await (await MockERC20A.mint(accountA.address, ethers.utils.parseEther('6.0'))).wait()
      return te.connect(accountA).create(
        [
          accountA.address, 0,
          [
            [MockERC721A.address, 0, 2], [MockERC1155A.address, 66, 6]
          ],
          [
            [MockERC20A.address, ethers.utils.parseEther('6.0')]
          ],
          0
        ],
        [
          accountB.address, ethers.utils.parseEther('29.0'),
          [
            [MockERC721B.address, 0, 3], [MockERC1155B.address, 88, 8],
            [ethers.constants.AddressZero, 0, 0],
          ],
          [
            [MockERC20B.address, ethers.utils.parseEther('8.0')],
            [ethers.constants.AddressZero, 0, 0],
          ],
          0
        ],
        { value: ethers.utils.parseEther('20.0') })
    }

    await (await initSwap()).wait()
    expect(await te._swapsCounter()).to.eq(1)

    // Offer status is open
    offer = await te._swaps(1)
    expect(offer.status).to.eq(1)

    await te.connect(accountA).cancel(1)

    // Offer status is canceled
    offer = await te._swaps(1)
    expect(offer.status).to.eq(2)
    await expect(te.connect(accountB).accept(1)).to.be.rejectedWith("DFKEarn: Swap closed.")
    await expect(te.connect(accountA).cancel(1)).to.be.rejectedWith("DFKEarn: status not open")

    // After the contract is cancelled, item A is not changed
    expect(await MockERC20A.balanceOf(accountA.address)).to.eq(ethers.utils.parseEther('6.0'))
    expect(await MockERC721A.ownerOf(3)).to.eq(accountA.address)
    expect(await MockERC1155A.balanceOf(accountA.address, 6)).to.eq(66)

    // Contract owner accounts have not changed
    end_bl = await ethers.provider.getBalance(owner)
    expect(end_bl).to.eq(start_bl)
  })

  it('Should charge fee success', async function () {
    // Set sell fee to 1 unit
    // (await te.setoffer1Fee(fee1)).wait()
    let f1 = await te.offer1Fee()
    var native1 = ethers.utils.parseEther("3")
    var native2 = ethers.utils.parseEther("29")
    const unnamed = await getUnnamedAccounts()
    const accountC = await ethers.getSigner(unnamed[2])
    async function initSwap (value = '1') {
      await (await MockERC721A.connect(accountC).mint(accountC.address, 3)).wait()
      await (await MockERC721A.connect(accountC).setApprovalForAll(te.address, true)).wait()
      await (await MockERC1155A.connect(accountC).setApprovalForAll(te.address, true)).wait()
      await (await MockERC1155A.connect(accountC).mint(accountC.address, 6, 66)).wait()
      await (await MockERC20A.connect(accountC).approve(te.address, ethers.utils.parseEther('6.0'))).wait()
      await (await MockERC20A.mint(accountC.address, ethers.utils.parseEther('6.0'))).wait()

      await (await MockERC721B.connect(accountB).mint(accountB.address, 3)).wait()
      await (await MockERC721B.connect(accountB).setApprovalForAll(te.address, true)).wait()
      await (await MockERC20B.mint(accountB.address, ethers.utils.parseEther('8.0'))).wait()
      await (await MockERC20B.connect(accountB).approve(te.address, ethers.utils.parseEther('8.0'))).wait()
      await (await MockERC1155B.connect(accountB).mint(accountB.address, 8, 88)).wait()
      await (await MockERC1155B.connect(accountB).setApprovalForAll(te.address, true)).wait()

      return te.connect(accountC).create(
        [
          accountC.address, native1,
          [
            [MockERC721A.address, 0, 2], [MockERC1155A.address, 66, 6]
          ],
          [
            [MockERC20A.address, ethers.utils.parseEther('6.0')]
          ],
          0
        ],
        [
          accountB.address, native2,
          [
            [MockERC721B.address, 0, 3], [MockERC1155B.address, 88, 8],
            [ethers.constants.AddressZero, 0, 0],
          ],
          [
          [MockERC20B.address, ethers.utils.parseEther('8.0')]
          ],
          0
        ],
        { value: ethers.utils.parseEther(value)})
    }

    const acceptSwap = (id = 1) => {
      return te.connect(accountB).accept(
        id, { value: native2.add(fee2) },
      )
    }
    // The number of coins sent is not enough to pay the sell fee
    await expect(initSwap('0')).to.be.rejectedWith('DFKEarn: Sent amount needs to be greater than or equal to the application fee')

    let start_bl = await ethers.provider.getBalance(te.address)

    var rc1 = await (await initSwap(ethers.utils.formatEther(native1.add(fee1)))).wait()
    var oid = rc1.events.find(e=>e.event=="Created").args.id
    expect(Number(oid), "offer id incorrect").to.eq(1)
    var end_bl = await ethers.provider.getBalance(te.address)
    expect(end_bl, `After creating an order, owner:${owner} The balance should be equal to the balance plus fee1 + native1`).to.eq(start_bl.add(fee1).add(native1))
    expect(await te._swapsCounter()).to.eq(1)

    var bl_b1 = await ethers.provider.getBalance(accountB.address)
    var bl_c1 = await ethers.provider.getBalance(accountC.address)
    start_bl = await ethers.provider.getBalance(owner)
    var tx =  await (await acceptSwap()).wait()

    var bl_b2 = await ethers.provider.getBalance(accountB.address)
    var bl_c2 = await ethers.provider.getBalance(accountC.address)
    var end_bl = await ethers.provider.getBalance(owner)
    // The contract owner receives 2 fees, one from the buyer and one from the seller

    expect(end_bl).to.eq(start_bl.add(fee2).add(fee1))
    expect(bl_b2, "Buyer's balance is incorrect").to.eq(bl_b1.add(native1).sub(fee2).sub(native2).sub(tx.gasUsed.mul(tx.effectiveGasPrice)))
    expect(bl_c2, "Seller's balance is incorrect").to.eq(bl_c1.add(native2))

    var offer = await te._swaps(oid)
    expect(offer.initiator.native, "Exchange completed for native1 balance").to.eq(native1)
    expect(offer.target.native, "Exchange completed for native2 balance").to.eq(native2)
    await expect(te.connect(accountC).cancel(oid)).to.be.rejectedWith("DFKEarn: status not open")

    await expect(te.connect(accountB).accept(1), "No re-deal after a deal").to.be.rejectedWith("DFKEarn: Swap closed.")
    await expect(te.connect(accountB).accept(3), "Orders cannot be traded without being created").to.be.rejectedWith("DFKEarn: Swap closed.")
    await expect(te.connect(accountC).cancel(3), "Orders not created cannot be cancelled").to.be.rejectedWith("DFKEarn: status not open")

  })
})

