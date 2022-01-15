// const KLT = artifacts.require("KLT");
const KollectPack = artifacts.require("KollectPack");
const KollectCard = artifacts.require("KollectCard");
const KollectRecipe = artifacts.require("KollectRecipe");
const KollectBook = artifacts.require("KollectBook");
const Kollect = artifacts.require("Kollect");

module.exports = async function(deployer) {
	// await deployer.deploy(KLT);
	await deployer.deploy(KollectPack);
	await deployer.deploy(KollectRecipe);
	await deployer.deploy(KollectCard, KollectPack.address, KollectRecipe.address);	
	await deployer.deploy(KollectBook, KollectCard.address);
	await deployer.deploy(Kollect, KollectCard.address, 
								   KollectPack.address);
};
