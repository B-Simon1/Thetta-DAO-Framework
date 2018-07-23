var DaoBaseWithUnpackers = artifacts.require("./DaoBaseWithUnpackers");
var StdDaoToken = artifacts.require("./StdDaoToken");
var DaoStorage = artifacts.require("./DaoStorage");

var WeiFund = artifacts.require("./WeiFund");
var MoneyFlow = artifacts.require("./MoneyFlow");
var IWeiReceiver = artifacts.require("./IWeiReceiver");
var WeiAbsoluteExpense = artifacts.require("./WeiAbsoluteExpense");
var InformalProposal = artifacts.require("./InformalProposal");

var MoneyflowAuto = artifacts.require("./MoneyflowAuto");

var InformalProposal = artifacts.require("./InformalProposal");

var Voting_Liquid = artifacts.require("./Voting_Liquid");
var Voting_SimpleToken = artifacts.require("./Voting_SimpleToken");
var IProposal = artifacts.require("./IProposal");

const BigNumber = web3.BigNumber;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

contract('Multiple Votings', (accounts) => {
	const creator   = accounts[0];
	const employee1 = accounts[1];
	const employee2 = accounts[2];

	let r2;
	let token;
	let voting;
	let daoBase;

	const VOTING_TYPE_1P1V = 1;
	const VOTING_TYPE_SIMPLE_TOKEN = 2;
	const VOTING_TYPE_QUADRATIC = 3;
	const VOTING_TYPE_LIQUID = 4;

	beforeEach(async() => {
		token = await StdDaoToken.new("StdToken","STDT",18, true, true, 1000000000);
		await token.mintFor(creator, 1);
		await token.mintFor(employee1, 1);
		await token.mintFor(employee2, 2);

		let store = await DaoStorage.new([token.address],{ from: creator });
		daoBase = await DaoBaseWithUnpackers.new(store.address,{ from: creator });

	});
	describe('getPowerOf()', function () {
		it('Check getPower() when 3 different votings created',async() => {

			// TODO: fix VOTING_TYPE_SIMPLE_TOKEN -> VOTING_TYPE_LIQUID
			let liquidVoting = await Voting_Liquid.new(daoBase.address, creator, creator, 0, 100, 100, token.address);
			let simpleVoting = await Voting_SimpleToken.new(daoBase.address, employee1, employee1, 60, '', 51, 71);
			let qudraticVoting = await Voting_Quadratic.new(daoBase.address, employee1, employee1, 60, 51, 71, token.address);

			r2 = await liquidVoting.getPowerOf(creator);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await liquidVoting.getPowerOf(employee1);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await liquidVoting.getPowerOf(employee2);
			assert.equal(r2.toNumber(),2,'yes');

			r2 = await simpleVoting.getPowerOf(creator);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await simpleVoting.getPowerOf(employee1);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await simpleVoting.getPowerOf(employee2);
			assert.equal(r2.toNumber(),2,'yes');

			r2 = await qudraticVoting.getPowerOf(creator);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await qudraticVoting.getPowerOf(employee1);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await qudraticVoting.getPowerOf(employee2);
			assert.equal(r2.toNumber(),1,'yes');

			token.transfer(creator, 1, {from: employee2});
			token.transfer(employee2, 1, {from: employee1});

			r2 = await liquidVoting.getPowerOf(creator);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await liquidVoting.getPowerOf(employee1);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await liquidVoting.getPowerOf(employee2);
			assert.equal(r2.toNumber(),2,'yes');

			r2 = await simpleVoting.getPowerOf(creator);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await simpleVoting.getPowerOf(employee1);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await simpleVoting.getPowerOf(employee2);
			assert.equal(r2.toNumber(),2,'yes');

			r2 = await qudraticVoting.getPowerOf(creator);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await qudraticVoting.getPowerOf(employee1);
			assert.equal(r2.toNumber(),1,'yes');

			r2 = await qudraticVoting.getPowerOf(employee2);
			assert.equal(r2.toNumber(),1,'yes');
		});
	});
});
