pragma solidity >=0.5.0 <0.9.0;

contract EnergyMarket {

    struct User {
        uint rate;                 // user rate utility plan (0 for flat rate, 1 for TOU)
        uint demand;               // user demand in Wh
        uint battery;              // does this user have a battery energy storage system (0 no, 1 yes)
        uint battery_charge;       // battery charge at the start of the current period (Wh)
        uint bid_peak;             // user energy bid price in c/kWh during peak periods
        uint bid_offpeak;          // user energy bid price in c/kWh during off peak periods
        uint ask_peak;             // user energy ask price in c/kWh during peak periods
        uint ask_offpeak;          // user energy ask price in c/kWh during off peak periods
        uint energy_excess;        // user total excess energy after covering own demand
        uint solar_capacity;       // user installed solar generation capacity in kW
        uint solar_excess;         // user solar excess energy after covering own demand
        uint balance;              // available balance for transactions (internal token)
    }

    mapping(address => User) public users;
    mapping(address => bool) public registered_user;
    uint numUsers = 0;

    // Initialize arrays to split users placing buying bids and users placing selling bids
    address[] all_users;
    address[] buy_users;
    address[] sell_users;

    // Set electric utility related rates
    uint flatRate = 20;         // rate to buy electricity from utility in c/kWh (flat rate customers)
    uint TOUrate_peak = 30;     // peak rate to buy electricity from utility in c/kWh (TOU customers)
    uint TOUrate_off = 3;       // off peak rate to buy electricity from utility in c/kWh (TOU customers)
    uint fit_price = 10;        // feed-rate-tariff (price in c/kWh at which grid buys excess solar power)

    // Initialize period type (0 for off peak and 1 for peak)
    uint period_type = 0;

    // battery capacity (Wh) and power rating (W) - assume same for all batteries
    uint batt_E = 12000;
    uint batt_P = 4000;

    // add new user to the descentralized energy trading platform
    function register(uint _rate, uint _solarCapacity, uint _battery) public {
        require(registered_user[msg.sender] == false, "User already registered");
        users[msg.sender].rate = _rate;
        users[msg.sender].solar_capacity = _solarCapacity;
        users[msg.sender].battery = _battery;
        users[msg.sender].battery_charge = 0;
        users[msg.sender].balance = 15000000;
        registered_user[msg.sender] = true;
        all_users.push(msg.sender);
        numUsers++;
    }

    // lets registered user change his own bidding rules
    function setBidAsk(uint _BidPk, uint _BidOffPk, uint _AskPk, uint _AskOffPk) public {
        users[msg.sender].bid_peak = _BidPk;
        users[msg.sender].bid_offpeak = _BidOffPk;
        users[msg.sender].ask_peak = _AskPk;
        users[msg.sender].ask_offpeak = _AskOffPk;
    }

    function userData() view public returns (uint[12] memory) {
        uint[12] memory val;
        val[0] = users[msg.sender].rate;
        val[1] = users[msg.sender].demand;
        val[2] = users[msg.sender].battery;
        val[3] = users[msg.sender].battery_charge;
        val[4] = users[msg.sender].bid_peak;
        val[5] = users[msg.sender].bid_offpeak;
        val[6] = users[msg.sender].ask_peak;
        val[7] = users[msg.sender].ask_offpeak;
        val[8] = users[msg.sender].energy_excess;
        val[9] = users[msg.sender].solar_capacity;
        val[10] = users[msg.sender].solar_excess;
        val[11] = users[msg.sender].balance;
        return val;
    }

    // place users buy and sell bids into two different arrays and sort them
    function sortBids() private {
        // reset arrays in case a user updated its bidding strategy. to be more efficient,
        // we can add some indicator of whether or not a user updated his strategy and avoid
        // this step completely
        delete buy_users; delete sell_users;

        // If peak period:
        if (period_type == 1) {

        // assign user addresses to corresponding buy bids and sell bids arrays
        for (uint i = 0; i < all_users.length; i++) {
            if (users[all_users[i]].bid_peak > 0) {buy_users.push(all_users[i]);}
            else {sell_users.push(all_users[i]);}
        }

        // descending sort of buy bids
        for (uint i = 0; i < buy_users.length; i++){
            for (uint j = i + 1; j < buy_users.length; j++) {
                address temp = buy_users[i];
                if (users[temp].bid_peak < users[buy_users[j]].bid_peak) {
                    buy_users[i] = buy_users[j];
                    buy_users[j] = temp;
                }
            }
        }

        // ascending sort of sell bids
        for (uint i = 0; i < sell_users.length; i++){
            for (uint j = i + 1; j < sell_users.length; j++) {
                address temp = sell_users[i];
                if (users[temp].ask_peak > users[sell_users[j]].ask_peak) {
                    sell_users[i] = sell_users[j];
                    sell_users[j] = temp;
                }
            }
        }
        } else // If off-peak period:
         {
                    // assign user addresses to corresponding buy bids and sell bids arrays
        for (uint i = 0; i < all_users.length; i++) {
            if (users[all_users[i]].bid_offpeak > 0) {buy_users.push(all_users[i]);}
            else {sell_users.push(all_users[i]);}
        }

        // descending sort of buy bids
        for (uint i = 0; i < buy_users.length; i++){
            for (uint j = i + 1; j < buy_users.length; j++) {
                address temp = buy_users[i];
                if (users[temp].bid_offpeak < users[buy_users[j]].bid_offpeak) {
                    buy_users[i] = buy_users[j];
                    buy_users[j] = temp;
                }
            }
        }

        // ascending sort of sell bids
        for (uint i = 0; i < sell_users.length; i++){
            for (uint j = i + 1; j < sell_users.length; j++) {
                address temp = sell_users[i];
                if (users[temp].ask_offpeak > users[sell_users[j]].ask_offpeak) {
                    sell_users[i] = sell_users[j];
                    sell_users[j] = temp;
                }
            }
        }

        }
    }

    // update demand and solar irradiation for current period. calculate excess energy for each user, depending on 
    // the time period (peak vs off-peak)
    function updateDI(uint[] memory _demand, uint _irradiance, uint _periodtype) private {
        period_type = _periodtype;
        uint _solar_energy;
        uint _batt_energy;
        // For peak period
        if (period_type == 1){
        for (uint i = 0; i < all_users.length; i++) {
            // calculate available solar power and battery power for the current period
            users[all_users[i]].demand = _demand[i];
            _solar_energy = users[all_users[i]].solar_capacity*_irradiance*1000;
            if (users[all_users[i]].battery_charge >= batt_P) {_batt_energy = batt_P;}
            else {_batt_energy = users[all_users[i]].battery_charge;}
            
            // calculate excess energy (if any) and demand not meet by PV or battery resources. calculate solar energy
            // recall that we are not allowed to sell battery energy to the grid
            if (users[all_users[i]].demand <= _batt_energy) {
                users[all_users[i]].energy_excess =  _solar_energy + _batt_energy - users[all_users[i]].demand;
                users[all_users[i]].solar_excess =  _solar_energy;
                users[all_users[i]].battery_charge -= _batt_energy - users[all_users[i]].demand;
                users[all_users[i]].demand = 0;
            } else if (users[all_users[i]].demand < _solar_energy + _batt_energy) {
                users[all_users[i]].energy_excess =  _solar_energy + _batt_energy - users[all_users[i]].demand;
                users[all_users[i]].solar_excess =  users[all_users[i]].energy_excess;
                users[all_users[i]].battery_charge -= _batt_energy;
                users[all_users[i]].demand = 0;
            } else {
                users[all_users[i]].energy_excess = 0;
                users[all_users[i]].demand -= _solar_energy + _batt_energy;
                users[all_users[i]].battery_charge -= _batt_energy;
            }
        } 
        
        // for off peak period:
        } else {
            for (uint i = 0; i < all_users.length; i++) {
                // calculate available solar power (there could be solar power, depending on the off peak period range)
                users[all_users[i]].demand = _demand[i];
                _solar_energy = users[all_users[i]].solar_capacity*_irradiance*1000;
                // set additional demand for battery charging, if applicable
                if (users[all_users[i]].battery == 1 && users[all_users[i]].battery_charge <= batt_E - batt_P) {
                    users[all_users[i]].demand += batt_P;
                    users[all_users[i]].battery_charge += batt_P;
                    }
                else if (users[all_users[i]].battery == 1 && users[all_users[i]].battery_charge >= batt_E - batt_P) {
                    users[all_users[i]].demand += batt_E - users[all_users[i]].battery_charge;
                    users[all_users[i]].battery_charge = batt_P;
                    }
                // calculate excess energy (if any) and demand not meet by PV or battery resources
                if (users[all_users[i]].demand < _solar_energy) {
                    users[all_users[i]].energy_excess =  _solar_energy - users[all_users[i]].demand;
                    users[all_users[i]].demand = 0;
                } else {
                    users[all_users[i]].energy_excess = 0;
                    users[all_users[i]].demand -= _solar_energy;
                }
            }
        }
    }

    // clears market for current period
    function clearMarket(uint[] memory _demand, uint _irradiance, uint _periodtype) public {
        updateDI(_demand, _irradiance, _periodtype);
        sortBids();
        uint j_init = 0;
        uint txprice = 0;
        // P2P energy trading

        // Peak period
        if (period_type == 1){
        for (uint i = 0; i < sell_users.length; i++) {
            if (users[buy_users[i]].bid_peak < users[sell_users[j_init]].ask_peak) {break;}
            for (uint j = j_init; j < buy_users.length; j++) {
                if (users[buy_users[i]].bid_peak < users[sell_users[j]].ask_peak) {break;}
                if (users[sell_users[i]].energy_excess >= users[buy_users[j]].demand) {
                    txprice = (users[buy_users[j]].bid_peak + users[sell_users[i]].ask_peak)/2;
                    users[buy_users[j]].balance -= txprice*users[buy_users[j]].demand;
                    users[sell_users[i]].balance += txprice*users[buy_users[j]].demand;
                    users[sell_users[i]].energy_excess -= users[buy_users[j]].demand;
                    users[buy_users[j]].demand = 0;
                    j_init++;
                } else if (users[sell_users[i]].energy_excess < users[buy_users[j]].demand) {
                    txprice = (users[buy_users[j]].bid_peak + users[sell_users[i]].ask_peak)/2;
                    users[buy_users[j]].balance -= txprice*users[sell_users[i]].energy_excess;
                    users[sell_users[i]].balance += txprice*users[sell_users[i]].energy_excess;
                    users[buy_users[j]].demand -= users[sell_users[i]].energy_excess;
                    users[sell_users[i]].energy_excess = 0;
                    break;
                }
            }
        }
        } else {
        // Off Peak period
        for (uint i = 0; i < sell_users.length; i++) {
            if (users[buy_users[i]].bid_offpeak < users[sell_users[j_init]].ask_offpeak) {break;}
            for (uint j = j_init; j < buy_users.length; j++) {
                if (users[buy_users[i]].bid_offpeak < users[sell_users[j]].ask_offpeak) {break;}
                if (users[sell_users[i]].energy_excess >= users[buy_users[j]].demand) {
                    txprice = (users[buy_users[j]].bid_offpeak + users[sell_users[i]].ask_offpeak)/2;
                    users[buy_users[j]].balance -= txprice*users[buy_users[j]].demand;
                    users[sell_users[i]].balance += txprice*users[buy_users[j]].demand;
                    users[sell_users[i]].energy_excess -= users[buy_users[j]].demand;
                    users[buy_users[j]].demand = 0;
                    j_init++;
                } else if (users[sell_users[i]].energy_excess < users[buy_users[j]].demand) {
                    txprice = (users[buy_users[j]].bid_offpeak + users[sell_users[i]].ask_offpeak)/2;
                    users[buy_users[j]].balance -= txprice*users[sell_users[i]].energy_excess;
                    users[sell_users[i]].balance += txprice*users[sell_users[i]].energy_excess;
                    users[buy_users[j]].demand -= users[sell_users[i]].energy_excess;
                    users[sell_users[i]].energy_excess = 0;
                    break;
                }
            }
        }
        }

        // Settle remaining energy balances with the grid (can't sell excess battery power to the grid)
        for (uint i = 0; i < sell_users.length; i++) {
            if (users[sell_users[i]].energy_excess > 0 && users[sell_users[i]].solar_excess <= users[sell_users[i]].energy_excess) {
                users[sell_users[i]].balance += users[sell_users[i]].solar_excess*fit_price;
            } else if (users[sell_users[i]].energy_excess > 0 && users[sell_users[i]].solar_excess > users[sell_users[i]].energy_excess) {
                users[sell_users[i]].balance += users[sell_users[i]].energy_excess*fit_price;
            }
        }
        for (uint i = 0; i < all_users.length; i++) {
            if (users[all_users[i]].demand > 0) {
                if (users[all_users[i]].rate == 0){users[all_users[i]].balance -= users[all_users[i]].demand*flatRate;}
                else if (users[all_users[i]].rate == 1 && period_type == 1){users[all_users[i]].balance -= users[all_users[i]].demand*TOUrate_peak;}
                else if (users[all_users[i]].rate == 1 && period_type == 0){users[all_users[i]].balance -= users[all_users[i]].demand*TOUrate_off;}
            }
        }
    }
}