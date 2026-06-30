public with sharing class RSBankDashboardController {

    public class TransferResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String transactionId;
        @AuraEnabled public Decimal newBalance;
    }

    @AuraEnabled
    public static TransferResult transferFunds(
        String fromAccountNumber,
        String toAccountNumber,
        Decimal amount,
        String description
    ) {

        BankingOperationsService.BankingOperationRequest req =
            new BankingOperationsService.BankingOperationRequest();

        req.operationType = 'TRANSFER';
        req.accountNumber = fromAccountNumber;
        req.toAccountNumber = toAccountNumber;
        req.amount = amount;
        req.description = description;

        List<BankingOperationsService.BankingOperationResponse> responses =
            BankingOperationsService.performBankingOperation(
                new List<BankingOperationsService.BankingOperationRequest>{ req }
            );

        BankingOperationsService.BankingOperationResponse res = responses[0];

        TransferResult result = new TransferResult();
        result.success = res.success;
        result.message = res.message;
        result.transactionId = res.transactionId;
        result.newBalance = res.newBalance;

        return result;
    }
}