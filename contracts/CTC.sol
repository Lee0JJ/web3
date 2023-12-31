// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/PlatformFee.sol";

contract CTCvC {
    modifier validOrganizerId(uint256 organizerId) {
        require(
            organizerId > 0 && organizerId <= numOrganizers,
            "Invalid organizerId"
        );
        _;
    }

    event ConcertCreated(address owner, uint256 concertId, uint256 date);

    event TicketPurchased(
        string owner,
        address concertOwner,
        uint256 time,
        uint256 concertId,
        uint256 zone
    );

    event OrganizerApplication(
        uint256 organizerId,
        string name,
        address account
    );

    event OrganizerUpdated(uint256 organizerId, string name, address account);

    event OrganizerVerified(uint256 organizerId, bool isVerified);

    event OrganizerArchived(uint256 organizerId);

    struct Concert {
        //Create By Who
        address owner;
        uint256 concertId;
        string name;
        uint256 date;
        string venue;
        uint256 numZones;
        //Map Price with available ticket amount
        uint256[][] zoneInfo;
        //Concert Image
        string[] imageUrl;
    }

    struct Organizer {
        uint256 organizerId;
        string name;
        address account;
        string[] documentUrl;
        bool isVerified;
        bool isArchived;
    }

    struct Ticket {
        string owner;
        uint256 time;
        uint256 concertId;
        uint256 zone;
        bool used;
    }

    address public admin;

    mapping(uint256 => Concert) public concerts;
    uint256 public numConcerts = 0;

    mapping(uint256 => Organizer) public organizers;
    uint256 public numOrganizers = 0;

    //Map customer device key with ticket
    mapping(string => Ticket[]) ticketOwned;

    constructor() {
        admin = msg.sender;
    }

    function setAdmin(address newAdmin) public  {
        require(msg.sender == admin, "No accesss on admin");
        admin = newAdmin;
    }

    function createConcert(
        uint256 concertId,
        string memory name,
        uint256 date,
        string memory venue,
        uint256 numZones,
        uint256[][] memory zoneInfo, // 2D array for zone information
        string[] memory imageUrl
    ) public {
        Concert storage concert = concerts[concertId];
        concert.owner = msg.sender;
        concert.concertId = concertId;
        concert.name = name;
        concert.date = date;
        concert.venue = venue;
        concert.numZones = numZones;
        concert.zoneInfo = zoneInfo;
        concert.imageUrl = imageUrl;
        if (concertId > numConcerts) {
            numConcerts++;
            emit ConcertCreated(msg.sender, concertId, date);
        }
    }

    function getConcertDetails(uint256 concertId)
        public
        view
        returns (
            address owner,
            string memory name,
            uint256 date,
            string memory venue,
            uint256 numZones,
            uint256[][] memory zoneInfo, // Updated to return zone information
            string[] memory imageUrl
        )
    {
        require(concertId > 0, "Invalid concertId");

        Concert storage concert = concerts[concertId];
        require(concert.concertId == concertId, "Concert not found");

        zoneInfo = concert.zoneInfo;

        return (
            concert.owner,
            concert.name,
            concert.date,
            concert.venue,
            concert.numZones,
            zoneInfo,
            concert.imageUrl
        );
    }

    function purchaseTickets(
        string memory uniqueId,
        uint256 concertId,
        uint256 zoneId,
        uint256 numTickets
    ) public payable {
        require(bytes(uniqueId).length > 0, "Unique ID cannot be empty");
        require(numTickets > 0, "Number of tickets must be greater than 0");

        Concert storage concert = concerts[concertId];
        require(concert.concertId == concertId, "Concert not found");
        require(zoneId > 0 && zoneId <= concert.numZones, "Invalid zoneId");

        // Check if there are enough available seats in the specified zone
        uint256 availableSeats = concert.zoneInfo[zoneId - 1][1];
        require(
            availableSeats >= numTickets,
            "Insufficient available seats in this zone"
        );

        (bool sent, ) = payable(concert.owner).call{value: msg.value}("");
        if (sent) {
            // Decrement the available seats in the specified zone
            concert.zoneInfo[zoneId - 1][1] -= numTickets;

            // Create and store multiple new tickets for the user
            for (uint256 i = 0; i < numTickets; i++) {
                Ticket memory newTicket = Ticket({
                    owner: uniqueId,
                    time: block.timestamp,
                    concertId: concertId,
                    zone: zoneId,
                    used: false
                });

                // Add the ticket to the user's ticketOwned mapping
                ticketOwned[uniqueId].push(newTicket);

                emit TicketPurchased(
                    uniqueId,
                    concert.owner,
                    block.timestamp,
                    concertId,
                    zoneId
                );
            }
        }
    }

    function getUserOwnedTickets(string memory owner)
        public
        view
        returns (Ticket[] memory)
    {
        return ticketOwned[owner];
    }

    //Organizer Part
    function registerAsOrganizer(
        string memory name,
        string[] memory documentUrl
    ) public {
        numOrganizers++;
        organizers[numOrganizers] = Organizer(
            numOrganizers,
            name,
            msg.sender,
            documentUrl,
            false,
            false
        );
        emit OrganizerApplication(numOrganizers, name, msg.sender);
    }

    function getOrganizers() public view returns (Organizer[] memory) {
        Organizer[] memory allOrganizers = new Organizer[](numOrganizers);

        for (uint256 i = 0; i < numOrganizers; i++) {
            // Use '<' instead of '<='
            Organizer storage organizer = organizers[i + 1];

            allOrganizers[i] = organizer;
        }

        return allOrganizers;
    }

    function updateOrganizer(
        uint256 organizerId,
        string memory name,
        address account,
        string[] memory documentUrl,
        bool isVerified,
        bool isArchived
    ) public validOrganizerId(organizerId) {
        organizers[organizerId].name = name;
        organizers[organizerId].account = account;
        organizers[organizerId].documentUrl = documentUrl;
        organizers[organizerId].isVerified = isVerified;
        organizers[organizerId].isArchived = isArchived;

        emit OrganizerUpdated(organizerId, name, account);
    }

    function setOrganizerVerificationStatus(
        uint256 organizerId,
        bool isVerified
    ) public validOrganizerId(organizerId) {
        organizers[organizerId].isVerified = isVerified;
        emit OrganizerVerified(organizerId, isVerified);
    }

    function archiveOrganizer(uint256 organizerId)
        public
        validOrganizerId(organizerId)
    {
        organizers[organizerId].isArchived = true;
        emit OrganizerArchived(organizerId);
    }

    function getOrganizerDocumentUrls(uint256 organizerId)
        public
        view
        validOrganizerId(organizerId)
        returns (string[] memory)
    {
        return organizers[organizerId].documentUrl;
    }

    function getConcerts() public view returns (Concert[] memory) {
        Concert[] memory allConcerts = new Concert[](numConcerts);

        for (uint256 i = 0; i < numConcerts; i++) {
            Concert storage concert = concerts[i + 1]; // Note: Concerts are stored starting from index 1

            allConcerts[i] = concert;
        }

        return allConcerts;
    }

    function useTicket(string memory uniqueId, uint256[] memory ticketIds)
        public
    {
        for (uint256 i = 0; i < ticketIds.length; i++) {
            uint256 ticketId = ticketIds[i];
            require(
                ticketId > 0 && ticketId <= ticketOwned[uniqueId].length,
                "Invalid ticket ID"
            );
            Ticket storage ticket = ticketOwned[uniqueId][ticketId - 1]; // Subtract 1 to get the correct index

            require(!ticket.used, "Ticket has already been used");

            // Mark the ticket as used
            ticket.used = true;
        }
    }
}
