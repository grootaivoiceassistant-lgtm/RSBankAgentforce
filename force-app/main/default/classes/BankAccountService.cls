public class BankAccountService {
    
    // CREATE
    public static String createBankAccount(Account accountHolder, String accountType, Decimal initialDeposit) {
       // try {
            RS_Bank_Account__c newAccount = new RS_Bank_Account__c();
        	newAccount.Name = accountHolder.First_Name__c +' '+ accountHolder.Last_Name__c;
            newAccount.Account_Holder__c = accountHolder.Id;
            newAccount.Account_Type__c = accountType;
            newAccount.Balance__c = initialDeposit;
            newAccount.Account_Status__c = 'Active';
            newAccount.Opening_Date__c = Date.today();
            newAccount.Account_Number__c = generateAccountNumber();
            
            insert newAccount;
            
            // Create initial deposit transaction
            if (initialDeposit > 0) {
                createTransaction(newAccount.Id, 'Credit', initialDeposit, 'Initial Deposit');
            }
            
            return newAccount.Account_Number__c;
        //} catch (Exception e) {
            //throw new AuraHandledException('Error creating bank account: ' + e.getMessage());
        //}
    }
    
    // READ
    public static List<RS_Bank_Account__c> getBankAccounts(Id accountHolderId) {
        return [SELECT Id, Account_Number__c, Account_Type__c, Balance__c, 
                Account_Status__c, Opening_Date__c 
                FROM RS_Bank_Account__c 
                WHERE Account_Holder__c = :accountHolderId];
    }
    
    // UPDATE
    public static void updateAccountBalance(Id bankAccountId, Decimal newBalance) {
        RS_Bank_Account__c account = new RS_Bank_Account__c(Id = bankAccountId);
        account.Balance__c = newBalance;
        update account;
    }
    
    // DELETE (Soft Delete)
    public static void closeBankAccount(Id bankAccountId) {
        RS_Bank_Account__c account = new RS_Bank_Account__c(Id = bankAccountId);
        account.Account_Status__c = 'Closed';
        update account;
    }
    
    // Utility Methods
    private static String generateAccountNumber() {
        String prefix = 'RSB';
        String randomNum = String.valueOf(Math.round(Math.random() * 100));
        return prefix + randomNum.leftPad(8, '0');
    }
    
    private static void createTransaction(Id bankAccountId, String type, Decimal amount, String description) {
        // Query the bank account record first
    RS_Bank_Account__c bankAcc = [
        SELECT Name 
        FROM RS_Bank_Account__c 
        WHERE Id = :bankAccountId 
        LIMIT 1
    ];
    
        Transaction__c transactions = new Transaction__c();
        transactions.Name = bankAcc.Name; // Assign the Name from the queried record
        transactions.Bank_Account__c = bankAccountId;
        transactions.Transaction_Type__c = type;
        transactions.Amount__c = amount;
        transactions.Description__c = description;
        transactions.Transaction_Date__c = System.now();
        transactions.Transaction_Status__c = 'Completed';
        
        insert transactions;
    }
}