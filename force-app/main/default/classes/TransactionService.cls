public class TransactionService {
    
    // CREATE Transaction
    public static String processTransaction(String accountNumber, String transactionType, 
                                         Decimal amount, String description) {
        try {
            RS_Bank_Account__c account = getBankAccountByNumber(accountNumber);
            
            // Validate sufficient balance for debit
            if (transactionType == 'Debit' && account.Balance__c < amount) {
                throw new AuraHandledException('Insufficient balance');
            }
            
            Transaction__c transactions = new Transaction__c();
            transactions.Bank_Account__c = account.Id;
            transactions.Transaction_Type__c = transactionType;
            transactions.Amount__c = amount;
            transactions.Description__c = description;
            transactions.Transaction_Date__c = System.now();
            transactions.Transaction_Status__c = 'Pending';
            
            insert transactions;
            
            // Update account balance
            Decimal newBalance = account.Balance__c;
            if (transactionType == 'Credit') {
                newBalance += amount;
            } else if (transactionType == 'Debit') {
                newBalance -= amount;
            }
            
            BankAccountService.updateAccountBalance(account.Id, newBalance);
            
            // Update transaction status
            transactions.Transaction_Status__c = 'Completed';
            transactions.Running_Balance__c = newBalance;
            update transactions;
            
            return transactions.Transaction_ID__c;
            
        } catch (Exception e) {
            throw new AuraHandledException('Transaction failed: ' + e.getMessage());
        }
    }
    
    // READ Transactions
    public static List<Transaction__c> getTransactionHistory(String accountNumber, Integer limitRecords) {
        RS_Bank_Account__c account = getBankAccountByNumber(accountNumber);
        
        return [SELECT Transaction_ID__c, Transaction_Type__c, Amount__c, 
                Transaction_Date__c, Description__c, Running_Balance__c, Transaction_Status__c
                FROM Transaction__c 
                WHERE Bank_Account__c = :account.Id 
                ORDER BY Transaction_Date__c DESC 
                LIMIT :limitRecords];
    }
    
    // Fund Transfer
    public static String transferFunds(String fromAccount, String toAccount, Decimal amount, String description) {
        try {
            // Debit from source account
            String debitTransactionId = processTransaction(fromAccount, 'Debit', amount, 'Transfer to ' + toAccount + ' - ' + description);
            
            // Credit to destination account
            String creditTransactionId = processTransaction(toAccount, 'Credit', amount, 'Transfer from ' + fromAccount + ' - ' + description);
            
            return 'Transfer completed. Debit: ' + debitTransactionId + ', Credit: ' + creditTransactionId;
            
        } catch (Exception e) {
            throw new AuraHandledException('Transfer failed: ' + e.getMessage());
        }
    }
    
    private static RS_Bank_Account__c getBankAccountByNumber(String accountNumber) {
        List<RS_Bank_Account__c> accounts = [SELECT Id, Balance__c FROM RS_Bank_Account__c WHERE Account_Number__c = :accountNumber LIMIT 1];
        if (accounts.isEmpty()) {
            throw new AuraHandledException('Account not found');
        }
        return accounts[0];
    }
}