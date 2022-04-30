pragma solidity >=0.7.0 <0.9.0;

contract P2PEnergyMarket {

    struct Energy{
      unit id;                    //Reference Id to Customer
      address sellinghousehold;  // Address Selling Household
      address buyinghousehold;  //Address Buying Household
      uint rate;                 // user rate utility plan (0 for flat rate, 1 for TOU)
      uint demand_profile;       // indicator for which demand profile to assign for this user
      uint256 demand;               // user demand in kWh
      uint256 buy_bid;         // user energy buying bid in c/kWh
      uint256 sell_offer;        // user energy selling bid in c/kWh
      uint256 solar_excess;         // user excess solar energy (total solar energy - demand)
      uint256 solar_capacity;       // user installed solar generation capacity in kW
      uint256 balance;              // available balance for transactions
    }

    mapping(uint => Energy) public energyBuyers;
    uint numBuyers;
    mapping(uint => Energy) public energySellers;
    uint numSellers;

    event bidEnergy(
      uint indexed _id,
      uint256 _demand,
      address indexed _buyinghousehold,
      uint256 _buy_bid
    );

    event sellEnergy(
      uint indexed _id,
      address indexed _sellinghousehold,
      uint256 _balance,
      uint256 _sell_offer
    );


    function makeABid() public {
      //New Household
      numBuyers++;

      //Store Bid
      energySellers[numBuyers] = Energy(
        numBuyers,
        0x0,
        msg.sender,
        0,
        _demand_profile,
        _demand,
        _buy_bid,
        0,
        0,
        0,
        0
        );

        bidEnergy(numBuyers, msg.sender, _demand, _buy_bid);
    }

    function makeASale() public {
      //New Household
      numSellers++;

      //Store Offer
      energySellers[numSellers] = Energy(
          numSellers,
          msg.sender,
          0x0,
          _rate,
          _demand_profile,
          _demand,
          0,
          _sell_offer,
          _solar_excess,
          _solar_capacity,
          _balance
        );

        sellEnergy(numSellers, msg.sender, _balance, _sell_offer);
    }

    function calculateAmountOffers() public {


    }

    function CalculateAmountBids() public {


    }

    function energyTransfer() public {


    }




}
