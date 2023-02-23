// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@thirdweb-dev/contracts/token/TokenERC1155.sol";

contract Contract is TokenERC1155 {
    /// @dev Collects and distributes the primary sale value of tokens being claimed.
    function collectPrice(MintRequest calldata _req) internal {
        if (_req.pricePerToken == 0) {
            return;
        }

        uint256 totalPrice = _req.pricePerToken * _req.quantity;
        // platform fee is flat fee
        uint256 platformFees = platformFeeBps;

        if (_req.currency == CurrencyTransferLib.NATIVE_TOKEN) {
            require(msg.value == totalPrice, "must send total price.");
        } else {
            require(msg.value == 0, "msg value not zero");
        }

        address saleRecipient = _req.primarySaleRecipient == address(0)
            ? primarySaleRecipient
            : _req.primarySaleRecipient;

        CurrencyTransferLib.transferCurrency(
            _req.currency,
            _msgSender(),
            platformFeeRecipient,
            platformFees
        );
        CurrencyTransferLib.transferCurrency(
            _req.currency,
            _msgSender(),
            saleRecipient,
            totalPrice - platformFees
        );
    }

    function mintWithSignature(
        MintRequest calldata _req,
        bytes calldata _signature
    ) external payable nonReentrant {
        address signer = verifyRequest(_req, _signature);
        address receiver = _req.to;

        uint256 tokenIdToMint;
        if (_req.tokenId == type(uint256).max) {
            tokenIdToMint = nextTokenIdToMint;
            nextTokenIdToMint += 1;
        } else {
            require(_req.tokenId < nextTokenIdToMint, "invalid id");
            tokenIdToMint = _req.tokenId;
        }

        if (_req.royaltyRecipient != address(0)) {
            royaltyInfoForToken[tokenIdToMint] = RoyaltyInfo({
                recipient: _req.royaltyRecipient,
                bps: _req.royaltyBps
            });
        }

        _mintTo(receiver, _req.uri, tokenIdToMint, _req.quantity);

        collectPrice(_req);

        emit TokensMintedWithSignature(signer, receiver, tokenIdToMint, _req);
    }
