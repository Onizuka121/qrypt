// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


contract QryptGiftCard {

    //definiamo qui la struttura della gift card
    struct GiftCard {
        address sender;          
        uint256 amount;        
        bytes32 segretoHash;      // hash del segreto
        address ephemeralWallet; // wallet effimero che utilizziamo per la 2FA ON-CHAIN
        bool    claimed;         
    }

    //teniamo traccia dell'ID dell'ultima gift card
    uint256 public lastGiftId;

    //teniamo traccia anche di una "mappa" delle gift card 
    mapping(uint256 => GiftCard) public gifts;

    //creaiamo/specifichiamo l'evento di quando la gift verra creata 
    event GiftCreated(
        uint256 indexed giftId, 
        address indexed sender,
        uint256 amount,
        address indexed ephemeralWallet
    );

//creaiamo/specifichiamo l'evento di quando la gift viene "ritirata"
    event GiftClaimed(
        uint256 indexed giftId,
        address indexed recipient,
        uint256 amount
    );

//creaiamo/specifichiamo l'evento di quando chi ha creato la gift card viene rimborsato (annulla la gift)
    event GiftRefunded(
        uint256 indexed giftId,
        address indexed sender,
        uint256 amount
    );

    // definiamo ora la funzione che crerà effettivamente la gift card 
    //specifichiamo inoltre che questa funzione dovra ritornare l'id della gift card creata
    function createGiftCard(
        bytes32 segretoHash,
        address ephemeralWallet
    ) external payable returns (uint256 giftId) {

        //controlliamo se l'importo che stiamo inviando è valido
        require(msg.value > 0, "Importo nullo"); 
        //controlliamo che il segreto non sia vuoto 
        require(segretoHash != bytes32(0), "segreto hash obbligatorio"); 
        //controlliamo che l'indirizzo del wallet effimero non sia vuoto 
        require(ephemeralWallet != address(0), "Ephemeral wallet obbligatorio");
        
        //assegnamo l'ultimo id della gift utilizzato +1
        giftId = lastGiftId+1;

        //creiamo ora una nuovo "elemento" gift card e lo mettiamo nella "mappa" delle gift card 
        // per tenere traccia 
        // inoltre passiamo tutti i dati della nuova gift card
        gifts[giftId] = GiftCard({
            sender: msg.sender,
            amount: msg.value,
            segretoHash: segretoHash,
            ephemeralWallet: ephemeralWallet,
            claimed: false
        });

        // creiamo ora effettivamente la gift card con i dati della nuova gift card
        emit GiftCreated(
            giftId,
            msg.sender,
            msg.value,
            ephemeralWallet
        );
    }


    // definiamo ora la funzione che ci permettera di ritirare/riscattare una gift card
    // utilizziamo calldata perché risulta più "economico" per il pagamento delle gas nel momento del claim
    // in questo modo si legge direttamente dalla transazione senza copiare
    function redeem(
        uint256 giftId,
        string calldata segreto,
        bytes calldata firma,
        address payable recipient
    ) external {
  
        //prendiamo la gift card secondo l'id dato in input
        //qui specifichiamo con storage per avere un riferimento alla gift card originale
        //in questo modo possiamo modificare la gift originale (impostazione di claimed)
        GiftCard storage g = gifts[giftId];

        // vari check 
        require(!g.claimed, "Gia' riscattata o rimborsata");
        require(g.amount > 0, "Gift inesistente");
        require(recipient != address(0), "Recipient non valido");


        // ---------- Check sulla sicurezza 2FA -------------------------
        
        // calcoliamo l'hash datoci in input da chi sta ritirando
        bytes32 providedHash = keccak256(abi.encodePacked(segreto));
        // check se giusto
        require(providedHash == g.segretoHash, "Segreto non valido");

        // creiamo ora il mesaggio unico per creare 
        // una firma digitale unica e sicura che viene creata 
        // unendo una stringa per specificare che si tratta di questa operazione di redeem e quindi firmiamo questa specifica operazione 
        // specifichiamo che la firma vale solo per questo contratto specifico (address(this)) 
        // specifichiamo la carta da ritirare 
        // specifichiamo infine l'indirizzo di chi sta ritirando, qui è dove utilizziamo la 2fa 
        bytes32 message = keccak256(
            abi.encodePacked("QRYPT_REDEEM", address(this), giftId, recipient)
        );

        // ora decifriamo la firma e troviamo l'indirizzo che l'ha creata  
        address recovered = _recoverSigner(message, firma);
        //controlliamo se l'indirizzo che firmato sia quello del wallet effimero
        require(recovered == g.ephemeralWallet, "Firma non valida");

        //quindi nel caso l'indirizzo sia giusto e sia quello dell'indirizzo del wallet effimero 
        //impostiamo i paramentri che la gift card è stata ritirata 
        g.claimed = true;
        //salviamoci prima l'amount
        uint256 amount = g.amount;
        g.amount = 0;

        //iniviamo ora l'amoount Avax a recipient 
        //inoltre catturiamo l'esito dell'invio 
        (bool ok, ) = recipient.call{value: amount}("");
        //controlliamo l'esito 
        require(ok, "Trasferimento fallito");


        //notifichiamo ora che la gift è stata riscattata 
        emit GiftClaimed(giftId, recipient, amount);
    
        //ps: per la parte UI possiamo "ascoltare" questa parte
        // per aggiornare che la gift è stata ritirata o far scattare l'invio di un messaggio di feedback


    }

    

    
    function refund(uint256 giftId) external {
        GiftCard storage g = gifts[giftId];

        require(msg.sender == g.sender, "Solo il creatore puo' richiedere il rimborso");
        require(!g.claimed, "Gia' riscattata o rimborsata");
        require(g.amount > 0, "Importo nullo");

        g.claimed = true;
        uint256 amount = g.amount;
        g.amount = 0;

        (bool ok, ) = payable(g.sender).call{value: amount}("");
        require(ok, "Rimborso fallito");

        emit GiftRefunded(giftId, g.sender, amount);
    }

    function _recoverSigner(
        bytes32 message,
        bytes memory firma
    ) internal pure returns (address) {
        require(firma.length == 65, "Firma non valida");

        bytes32 ethSignedMessage = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(firma, 32))
            s := mload(add(firma, 64))
            v := byte(0, mload(add(firma, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Valore v non valido");

        return ecrecover(ethSignedMessage, v, r, s);
    }
}
