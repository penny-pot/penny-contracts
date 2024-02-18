// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract VaultHelpers {
    enum PaymentInterval {
        Daily,
        Weekly,
        Monthly
    }

    struct Trade {
        uint256 total;
        uint256 settled;
        uint256[] dueDates;
        uint256[] amounts;
        bool[] paidDueDates;
        bool closed;
    }

    function initiateDueDates(
        uint256 currentTimestamp,
        uint256 splitsCount,
        PaymentInterval interval
    ) internal pure returns (uint256[] memory dueDates) {
        // Calculate the first due date based on the current timestamp
        uint256 nextDueDate = currentTimestamp;

        // Set the interval for subsequent due dates
        uint256 intervalInSeconds;

        if (interval == PaymentInterval.Daily) {
            intervalInSeconds = 1 days;
        } else if (interval == PaymentInterval.Weekly) {
            intervalInSeconds = 7 days;
        } else if (interval == PaymentInterval.Monthly) {
            intervalInSeconds = 30 days; // Assuming a month is 30 days
        }
        dueDates = new uint256[](splitsCount);
        for (uint256 i = 0; i < splitsCount; i++) {
            dueDates[i] = nextDueDate;
            nextDueDate = nextDueDate + intervalInSeconds;
        }
        return dueDates;
    }

    // function initiateTrade(
    //     Trade storage trade,
    //     uint256 currentTimestamp,
    //     uint256 splitsCount,
    //     PaymentInterval interval,
    //     uint256 total
    // ) internal {
    //     // Calculate the first due date based on the current timestamp
    //     uint256 nextDueDate = currentTimestamp;
    //     // Set the interval for subsequent due dates
    //     uint256 intervalInSeconds = _getIntervalInSeconds(interval);
    //     // Populate the due dates and amounts arrays
    //     trade.dueDates = new uint256[](splitsCount);
    //     trade.amounts = new uint256[](splitsCount);
    //     for (uint256 i = 0; i < splitsCount; i++) {
    //         trade.dueDates[i] = nextDueDate;
    //         trade.amounts[i] = total / splitsCount;
    //         nextDueDate += intervalInSeconds;
    //     }
    // }

    function getRemainingSplits(
        Trade storage trade
    )
        internal
        view
        returns (uint256[] memory remainingAmounts, uint256[] memory dueDates)
    {
        uint256 unpaidCount = 0;
        for (uint256 i = 0; i < trade.dueDates.length; i++) {
            if (!trade.paidDueDates[i]) {
                unpaidCount++;
            }
        }
        dueDates = new uint256[](unpaidCount);
        remainingAmounts = new uint256[](unpaidCount);
        uint256 j = 0;
        for (uint256 i = 0; i < trade.dueDates.length; i++) {
            if (!trade.paidDueDates[i]) {
                dueDates[j] = trade.dueDates[i];
                remainingAmounts[j] = trade.amounts[i];
                j++;
            }
        }
        return (remainingAmounts, dueDates);
    }

    function _getIntervalInSeconds(
        uint256 interval
    ) internal pure returns (uint256) {
        if (interval == uint256(PaymentInterval.Daily)) {
            return 1 days;
        } else if (interval == uint256(PaymentInterval.Weekly)) {
            return 7 days;
        } else if (interval == uint256(PaymentInterval.Monthly)) {
            return 30 days; // Assuming a month is 30 days
        }
        revert("Invalid payment interval");
    }
}
