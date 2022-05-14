App = {
  web3Provider: null,
  contracts: {},
  period: 0,

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

    if ($('#battery :selected').text() == "Not installed") {
      var _battery = 0;} 
    else {
      var _battery = 1;
    }
  
    var _solar_capacity = parseInt($('#solar_capacity').val());
    
    web3.eth.getAccounts(function(error, accounts) {
      if (error) {
        console.log(error);
      }

      var account = accounts[0];

      App.contracts.EnergyMarket.deployed().then(function(instance) {
        EnergyMarketInstance = instance;
        return EnergyMarketInstance.register(_rate, _solar_capacity, _battery, {from: account});
      }).then(function(result) {alert(result)
      }).catch(function(err) {
        alert(err);
      });
    });
  },

  setBidAsk: function() {
    var EnergyMarketInstance;
    var _bidpeak = parseInt($('#bid_peak').val());
    var _bidoffpeak = parseInt($('#bid_offpeak').val());
    var _askpeak = parseInt($('#ask_peak').val());
    var _askoffpeak = parseInt($('#ask_offpeak').val());

    web3.eth.getAccounts(function(error, accounts) {
      if (error) {
        console.log(error);
      }

      var account = accounts[0];

      App.contracts.EnergyMarket.deployed().then(function(instance) {
        EnergyMarketInstance = instance;
        return EnergyMarketInstance.setBidAsk(_bidpeak, _bidoffpeak, _askpeak, _askoffpeak, {from: account});
      }).then(function(result) {
      }).catch(function(err) {
        alert(err);
      });
    });

  },

  userData: function() {
    var _rate; var _battery; 

    web3.eth.getAccounts(function(error, accounts) {
      if (error) {
        console.log(error);
      }
      var account = accounts[0];
        App.contracts.EnergyMarket.deployed().then(function(instance) {
          EnergyMarketInstance = instance;
          return EnergyMarketInstance.userData({from: account});
        }).then(function(result) {
          if (result[0] == 0){_rate = "Flat Rate"} else {_rate = "TOU rate"}
          if (result[2] == 0){_battery = "Not installed"} else {_battery = "Installed"}

          alert(["Rate: "+_rate, "\r\nBattery storage: "+_battery, "\r\nBattery Charge: "+result[3],
                 "\r\nBid - Peak: "+result[4], "\r\nBid - Off Peak: "+result[5], "\r\nAsk - Peak: "+result[6],
                 "\r\nAsk - Off Peak: "+result[7], "\r\nSolar Capacity (kW): "+result[9], "\r\nBalance: "+result[11]])
        }).catch(function(err) {
          alert(err);
        });
    });
   },

  clearMarket: function(){
    var irradiance; var demand = []; var periodtype = 0;
    $.ajaxSetup({
      async: false
     });
    $.getJSON('../demand.json', function(data){
      for (i = 0; i < 20; i ++) {
        demand.push(data[App.period+1][i])
      }
    });

    $.getJSON('../irradiance.json', function(data){
        irradiance = data.Irradiance[App.period]
    });

    // Peak period defined as between 8am to 10pm. 0 if off peak, 1 if peak
    if ((App.period+1)%24 >= 8 && (App.period+1)%24 <= 22) {
       periodtype = 1;}
    else {periodtype = 0;}

    web3.eth.getAccounts(function(error, accounts) {
      if (error) {
        console.log(error);
      }

      var account = accounts[0];

      App.contracts.EnergyMarket.deployed().then(function(instance) {
        EnergyMarketInstance = instance;
        return EnergyMarketInstance.clearMarket(demand, irradiance, periodtype, {from: account});
      }).then(function(result) {alert("Market Cleared!")
      }).catch(function(err) {
        alert(err);
      });
    });

    App.period++

   }

};

$(function() {
  $(window).load(function() {
    App.init();
  });
});
