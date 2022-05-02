App = {
  web3Provider: null,
  contracts: {},

  init: async function() {
    return await App.initWeb3();
  },

  initWeb3: async function() {
    // Modern dapp browsers...
    if (window.ethereum) {
      App.web3Provider = window.ethereum;
      try {
        // Request account access
        await window.ethereum.request({ method: "eth_requestAccounts" });;
      } catch (error) {
        // User denied account access...
        console.error("User denied account access")
      }
    }
    // Legacy dapp browsers...
    else if (window.web3) {
      App.web3Provider = window.web3.currentProvider;
    }
    // If no injected web3 instance is detected, fall back to Ganache
    else {
      App.web3Provider = new Web3.providers.HttpProvider('http://localhost:7545');
    }
    web3 = new Web3(App.web3Provider);

    return App.initContract();
  },

  initContract: function() {
    $.getJSON('EnergyMarket.json', function(data) {
        // Get the necessary contrat artifact file and instantiate it with @truffle/contract
        var EnergyMarketArtifact = data;
        App.contracts.EnergyMarket = TruffleContract(EnergyMarketArtifact);

        // Set the provider for our contract
        App.contracts.EnergyMarket.setProvider(App.web3Provider);
    });
  },

  register: function() {
    var EnergyMarketInstance;
    
    if ($('#rate :selected').text() == "Flat") {
      var _rate = 0;} 
    else {
      var _rate = 1;
    }
  
    var _solar_capacity = parseInt($('#solar_capacity').val());
    
    web3.eth.getAccounts(function(error, accounts) {
      if (error) {
        console.log(error);
      }

      var account = accounts[0];

      App.contracts.EnergyMarket.deployed().then(function(instance) {
        EnergyMarketInstance = instance;
        return EnergyMarketInstance.register(_rate, _solar_capacity, {from: account});
      }).then(function(result) {
      }).catch(function(err) {
        alert(err);
      });
    });
  }

};

$(function() {
  $(window).load(function() {
    App.init();
  });
});
