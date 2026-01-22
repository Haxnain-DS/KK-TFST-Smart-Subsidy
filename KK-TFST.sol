// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// [Fix: Named Imports] explicitly importing symbols reduces compiler ambiguity
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// ==========================================
// 1. ELIGIBILITY CONTRACT
// ==========================================
contract EligibilityRegistry is AccessControl {
    
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    uint256 public constant MAX_LAND_LIMIT = 1250; // 12.50 Acres

    // [Fix: Custom Errors] Saves gas and fixes "Error message too long"
    error InvalidAddress();
    error InvalidCNIC();
    error LandLimitExceeded();
    
    struct FarmerProfile {
        bytes32 cnicHash;
        uint256 landAcres;
        bool isVerified;
    }

    mapping(address => FarmerProfile) public farmerProfiles; // [Fix: Renamed to avoid confusion]

    event FarmerVerified(address indexed farmer, uint256 landSize);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
    }

    // [Fix: string calldata] Cheaper than 'memory' for external functions
    function registerFarmer(address _wallet, string calldata _cnic, uint256 _landSize) external onlyRole(VERIFIER_ROLE) {
        if (_wallet == address(0)) revert InvalidAddress();
        if (bytes(_cnic).length == 0) revert InvalidCNIC();
        if (_landSize >= MAX_LAND_LIMIT) revert LandLimitExceeded();
        
        farmerProfiles[_wallet] = FarmerProfile({
            cnicHash: keccak256(abi.encodePacked(_cnic)),
            landAcres: _landSize,
            isVerified: true
        });

        emit FarmerVerified(_wallet, _landSize);
    }

    // [Fix: Renamed argument] _farmerAddress distinguishes it from the mapping
    function isEligible(address _farmerAddress) external view returns (bool) {
        return farmerProfiles[_farmerAddress].isVerified;
    }
}

// ==========================================
// 2. SUPPLY CHAIN & SETTLEMENT CONTRACT
// ==========================================
contract FertilizerSupplyChain is ERC20, AccessControl, ReentrancyGuard {
    
    EligibilityRegistry public eligibilityContract;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DEALER_MANAGER_ROLE = keccak256("DEALER_MANAGER_ROLE");

    mapping(address => bool) public authorizedDealers;

    // [Fix: Custom Errors]
    error InvalidContractAddress();
    error InvalidDealerAddress();
    error InvalidFarmerAddress();
    error FarmerNotVerified();
    error UnauthorizedDealer();
    error InsufficientBalance();
    error InvalidBankDetails();
    error UnauthorizedCall();

    event SubsidyIssued(address indexed farmer, uint256 amount);
    event PhysicalBagHandover(address indexed farmer, address indexed dealer, uint256 bags);
    event SettlementTriggered(address indexed dealer, uint256 amountTokens, string bankDetails);

    constructor(address _eligibilityContractAddress) ERC20("Govt Fertilizer Subsidy", "GFS") {
        if (_eligibilityContractAddress == address(0)) revert InvalidContractAddress();
        
        eligibilityContract = EligibilityRegistry(_eligibilityContractAddress);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(DEALER_MANAGER_ROLE, msg.sender);
    }

    // --- GOVT FUNCTIONS ---

    function authorizeDealer(address _dealer) external onlyRole(DEALER_MANAGER_ROLE) {
        if (_dealer == address(0)) revert InvalidDealerAddress();
        authorizedDealers[_dealer] = true;
    }

    function issueSubsidy(address _farmer, uint256 _amount) external onlyRole(MINTER_ROLE) {
        if (_farmer == address(0)) revert InvalidFarmerAddress();

        // [Fix: Checks-Effects-Interaction Pattern]
        // 1. Interaction (Read external data)
        bool isVerified = eligibilityContract.isEligible(_farmer);
        
        // 2. Check (Validate data)
        if (!isVerified) revert FarmerNotVerified();
        
        // 3. Effect (Update state / Mint)
        _mint(_farmer, _amount);
        emit SubsidyIssued(_farmer, _amount);
    }

    // --- FARMER FUNCTIONS ---

    function transfer(address recipient, uint256 amount) public override nonReentrant returns (bool) {
        if (!authorizedDealers[recipient]) revert UnauthorizedDealer();
        
        bool success = super.transfer(recipient, amount);
        
        if(success) {
            emit PhysicalBagHandover(msg.sender, recipient, amount);
        }
        return success;
    }

    // --- DEALER FUNCTIONS ---

    function redeemForSettlement(uint256 _amount, string calldata _bankAccountID) external nonReentrant {
        if (!authorizedDealers[msg.sender]) revert UnauthorizedCall();
        if (balanceOf(msg.sender) < _amount) revert InsufficientBalance();
        if (bytes(_bankAccountID).length == 0) revert InvalidBankDetails();

        _burn(msg.sender, _amount);
        emit SettlementTriggered(msg.sender, _amount, _bankAccountID);
    }
}