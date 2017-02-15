pragma solidity ^0.4.3;

contract StateChannel {

    address[] public players;
    mapping (address => uint) playermap;

    // State, indexed by round
    int bestRound = -1;
    int lastOpenRound = -1;

    enum Status { PENDING, OK }

    Status  status;
    uint deadline;
    mapping ( uint => bytes32[] ) inputs;

    bytes32 state;

    event EventPending (uint round, uint deadline);
    event EventOnchain (uint round);
    event EventOffchain(uint round);

    uint T1;
    uint T2;

    modifier after_ (uint T) { if (T > 0 && block.number >= T) _; else throw; }
    modifier before (uint T) { if (T == 0 || block.number <  T) _; else throw; }
    modifier onlyplayers { if (playermap[msg.sender] > 0) _; else throw; }
    modifier beforeTrigger { if (T1 == 0) _; else throw; }

    function applyUpdate(bytes32 state, bytes32[] inputs) returns(bytes32) {
	      // APPLICATION SPECIFIC UPDATE
	      return state;
    }

    function latestClaim() constant after_(T1) returns(int) {
        return(bestRound);
    }

    function assert(bool b) internal {
        if (!b) throw;
    }

    function verifySignature(address pub, bytes32 h, uint8 v, bytes32 r, bytes32 s) {
        if (pub != ecrecover(h,v,r,s)) throw;
    }

    function StateChannel(address[] _players) {
        // Assume this channel is funded by the sender
        for (uint i = 0; i < _players.length; i++) {
            players.push(_players[i]);
            playermap[_players[i]] = (i+1);
        }
    }

    // Allow a party to provide their on-chain input (only once) in case of trigger
    function provideInput(uint r, bytes32 input) onlyplayers {

        // FIXME: handle array initialization
	      uint i = playermap[msg.sender];
     	  assert(inputs[r][i] == 0);
	      inputs[r][i] = input;
    }

    // Causes a timeout for the next round to go on-chain
    function triggerT1(uint r) onlyplayers {
    	  assert( r == uint(bestRound + 1) ); // Requires the previous state to be registered
	      assert( status == Status.OK );

	      status = Status.PENDING;
	      deadline = block.number + 10; // Set the deadline for collecting inputs or updates

        EventPending(r, block.number);
    }

    function triggerT2(uint r) {
	      // No one has provided an "update" message in time
	      assert( r == uint(bestRound + 1) );
	      assert( status == Status.PENDING );
	      assert( block.number > deadline );

	      status = Status.OK;

	      // Process all the inputs, using defaults if necessary
	      state = applyUpdate(state, inputs[r]);
	      EventOnchain(r);
	      bestRound = int(r);
    }

    function update(uint[] sigs, int r, bytes32 _state) onlyplayers {
        // Only update to states with larger round number
        if (r <= bestRound)
	      return;

	      // Updates for a later round supercede any pending state
	      else if (status == Status.PENDING) {

            // Check the signature of all parties
           var _h = sha3(r, state);
           for (uint i = 0; i < players.length; i++) {
               var V = uint8 (sigs[i*3+0]);
          	   var R = bytes32(sigs[i*3+1]);
          	   var S = bytes32(sigs[i*3+2]);
          	   verifySignature(players[i], _h, V, R, S);

           }

	         status = Status.OK;
           bestRound = r;
	         EventOffchain(uint(bestRound));
           state = _state;
	      }
    }
}
