pragma solidity >=0.7.0 <0.9.0;

contract P2PEnergyMarket {

    struct User {
        uint rate;                 // user rate utility plan (0 for flat rate, 1 for TOU)
        uint demand_profile;       // indicator for which demand profile to assign for this user
        uint demand;               // user demand in kWh
        uint buy_bid_peak;         // user energy buying bid in c/kWh
        uint buy_bid_offpeak;      // user energy buying bid in c/kWh
        uint sell_bid_peak;        // user energy selling bid in c/kWh
        uint sell_bid_offpeak;     // user energy selling bid in c/kWh
        uint solar_excess;         // user excess solar energy (total solar energy - demand)
        uint solar_capacity;       // user installed solar generation capacity in kW
        uint balance;              // available balance for transactions
    }

    mapping(address => User) users;
    uint numUsers = 0;

    // Initialize arrays to split users placing buying bids and users placing selling bids
    address[] all_users;
    address[] buy_users;
    address[] sell_users;

    // Set electric utility related rates
    uint flatRate = 15;         // rate to buy electricity from utility in c/kWh (flat rate customers)
    uint TOUrate_peak = 25;     // peak rate to buy electricity from utility in c/kWh (TOU customers)
    uint TOUrate_off = 2;       // off peak rate to buy electricity from utility in c/kWh (TOU customers)
    uint fit_price = 8;         // feed-rate-tariff (price in c/kWh at which grid buys excess solar power)

    // initialize demand assignment integer
    uint demand_assign = 1;

    // initialize solar irradiation value
    uint irradiation = 1;

    // add new user to the descentralized energy trading platform
    function register(address toUser, uint _rate, uint _solarCapacity) public {
        users[toUser].rate = _rate;
        users[toUser].solar_capacity = _solarCapacity;
        users[toUser].demand_profile = demand_assign; demand_assign++;
        users[toUser].balance = 10000;
        all_users.push(toUser);
    }

    // getter function for the information of a user
    function getUserData(address toUser, uint _val) public view returns (uint) {
        uint val;
        if (_val == 0) {val = users[toUser].rate;}
        else if (_val == 1) {val = users[toUser].demand_profile;}
        else if (_val == 2) {val = users[toUser].demand;}
        else if (_val == 3) {val = users[toUser].buy_bid_peak;}
        else if (_val == 4) {val = users[toUser].sell_bid_peak;}
        else if (_val == 5) {val = users[toUser].solar_capacity;}
        else if (_val == 6) {val = users[toUser].solar_excess;}
        else {val = users[toUser].balance;}
        return val;
    }

    // lets registered user change his own bidding rules
    function setBuyBid(address toUser, uint _buyBidPk) public {
        users[toUser].buy_bid_peak = _buyBidPk;
        users[toUser].sell_bid_peak = 0;
    }
    function setSellBid(address toUser, uint _sellBidPk) public {
        users[toUser].sell_bid_peak = _sellBidPk;
        users[toUser].buy_bid_peak = 0;
    }

    // place users buy and sell bids into two different arrays and sort them
    function sortBids() private {
        // reset arrays in case a user updated its bidding strategy. to be more efficient,
        // we can add some indicator of whether or not a user updated his strategy and avoid
        // this step completely
        delete buy_users; delete sell_users;

        // assign user addresses to corresponding buy bids and sell bids arrays
        for (uint i = 0; i < all_users.length; i++) {
            if (users[all_users[i]].buy_bid_peak > 0) {buy_users.push(all_users[i]);}
            else {sell_users.push(all_users[i]);}
        }

        // descending sort of buy bids
        for (uint i = 0; i < buy_users.length; i++){
            for (uint j = i + 1; j < buy_users.length; j++) {
                address temp = buy_users[i];
                if (users[temp].buy_bid_peak < users[buy_users[j]].buy_bid_peak) {
                    buy_users[i] = buy_users[j];
                    buy_users[j] = temp;
                }
            }
        }

        // ascending sort of sell bids
        for (uint i = 0; i < sell_users.length; i++){
            for (uint j = i + 1; j < sell_users.length; j++) {
                address temp = sell_users[i];
                if (users[temp].sell_bid_peak > users[sell_users[j]].sell_bid_peak) {
                    sell_users[i] = sell_users[j];
                    sell_users[j] = temp;
                }
            }
        }
    }

    // update demand and solar irradiation for current period
    function updateDI(uint[] memory _demand, uint _irradiation) public {
        irradiation = _irradiation;
        for (uint i = 0; i < all_users.length; i++) {
            users[all_users[i]].demand = _demand[users[all_users[i]].demand_profile];
            if (users[all_users[i]].demand < users[all_users[i]].solar_capacity*irradiation) {
                users[all_users[i]].solar_excess = users[all_users[i]].solar_capacity*irradiation - users[all_users[i]].demand;
                users[all_users[i]].demand = 0;
            } else {users[all_users[i]].solar_excess = 0;}
        }
    }

    // clears market for current period
    function clearMarket() public {
        sortBids();
        uint j_init = 0;
        uint txprice = 0;
        // P2P energy trading
        for (uint i = 0; i < sell_users.length; i++) {
            if (users[buy_users[i]].buy_bid_peak < users[sell_users[j_init]].sell_bid_peak) {break;}
            for (uint j = j_init; j < buy_users.length; j++) {
                if (users[buy_users[i]].buy_bid_peak < users[sell_users[j]].sell_bid_peak) {break;}
                if (users[sell_users[i]].solar_excess >= users[buy_users[j]].demand) {
                    txprice = (users[buy_users[j]].buy_bid_peak + users[sell_users[i]].sell_bid_peak)/2;
                    users[buy_users[j]].balance -= txprice*users[buy_users[j]].demand;
                    users[sell_users[i]].balance += txprice*users[buy_users[j]].demand;
                    users[sell_users[i]].solar_excess -= users[buy_users[j]].demand;
                    users[buy_users[j]].demand = 0;
                    j_init++;
                } else if (users[sell_users[i]].solar_excess < users[buy_users[j]].demand) {
                    txprice = (users[buy_users[j]].buy_bid_peak + users[sell_users[i]].sell_bid_peak)/2;
                    users[buy_users[j]].balance -= txprice*users[sell_users[i]].solar_excess;
                    users[sell_users[i]].balance += txprice*users[sell_users[i]].solar_excess;
                    users[buy_users[j]].demand -= users[sell_users[i]].solar_excess;
                    users[sell_users[i]].solar_excess = 0;
                    break;
                }
            }
        }
        // Settle remaining energy balances with the grid
        for (uint i = 0; i < sell_users.length; i++) {
            if (users[sell_users[i]].solar_excess > 0) {
                users[sell_users[i]].balance += users[sell_users[i]].solar_excess*fit_price;
            }
        }
        for (uint i = 0; i < all_users.length; i++) {
            if (users[all_users[i]].demand > 0) {
                if (users[all_users[i]].rate == 0){users[all_users[i]].balance -= users[all_users[i]].demand*flatRate;}
                else if (users[all_users[i]].rate == 1){users[all_users[i]].balance -= users[all_users[i]].demand*TOUrate_peak;}
            }
        }
    }
}