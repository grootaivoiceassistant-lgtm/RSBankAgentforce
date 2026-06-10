public with sharing class BankDashboardService {

    @AuraEnabled(cacheable=true)
    public static RS_Bank_Account__c getBankAccountForUser() {
        Id userId = UserInfo.getUserId();
        User u = [SELECT Email FROM User WHERE Id = :userId LIMIT 1];
        System.debug('u--'+u);
        if (u.Email == null) {
            throw new AuraHandledException('No contact associated with the user.');
        }
        List<RS_Bank_Account__c> accounts = [
            SELECT Id, Name, Account_Number__c, Account_Type__c, Balance__c, 
                   Account_Status__c, Opening_Date__c, Customer_Email__c, 
                   Customer_Phone__c, Nominee__c, PAN_Card_Number__c
            FROM RS_Bank_Account__c 
            WHERE Customer_Email__c = :u.Email 
            LIMIT 1
        ];
        System.debug('accounts--'+accounts);
        if (accounts.isEmpty()) {
            throw new AuraHandledException('No bank account found for the user.');
        }
        return accounts[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<Transaction__c> getRecentTransactionsForUser(Integer limitCount) {
        if (limitCount == null || limitCount <= 0) {
            limitCount = 5;
        }
        if (limitCount > 20) {
            limitCount = 20; // Security limit
        }
        Id userId = UserInfo.getUserId();
        User u = [SELECT Email FROM User WHERE Id = :userId LIMIT 1];
        System.debug('u--'+u);
        if (u.Email == null) {
            throw new AuraHandledException('No contact associated with the user.');
        }
        List<RS_Bank_Account__c> accounts = [
            SELECT Id , Account_Number__c
            FROM RS_Bank_Account__c 
            WHERE Customer_Email__c = :u.Email 
            LIMIT 1
        ];
        System.debug('accounts--'+accounts);
        if (accounts.isEmpty()) {
            throw new AuraHandledException('No bank account found for the user.');
        }
        Id accountId = accounts[0].Id;
        return [
            SELECT Id, Transaction_Date__c, Description__c, Amount__c 
            FROM Transaction__c 
            WHERE Bank_Account__c = :accountId 
            ORDER BY Transaction_Date__c DESC 
            LIMIT :limitCount
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Decimal getLoanBalanceForUser() {
        Id userId = UserInfo.getUserId();
        User u = [SELECT Email FROM User WHERE Id = :userId LIMIT 1];
        if (u.Email == null) {
            return 0;
        }
        List<Loan__c> loans = [
            SELECT Outstanding_Amount__c 
            FROM Loan__c 
            WHERE Account_Holder__c = :u.ContactId 
            AND Loan_Status__c = 'Active' 
            LIMIT 1
        ];
        return loans.isEmpty() ? 0 : loans[0].Outstanding_Amount__c;
    }

    @AuraEnabled(cacheable=true)
    public static Decimal getCreditAvailableForUser() {
        Id userId = UserInfo.getUserId();
        User u = [SELECT ContactId FROM User WHERE Id = :userId LIMIT 1];
        if (u.ContactId == null) {
            return 0;
        }
        List<RS_Bank_Account__c> accounts = [
            SELECT Id 
            FROM RS_Bank_Account__c 
            WHERE Account_Holder__c = :u.ContactId 
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            return 0;
        }
        Id accountId = accounts[0].Id;
        List<Card__c> cards = [
            SELECT Available_Limit__c 
            FROM Card__c 
            WHERE Bank_Account__c = :accountId 
            LIMIT 1
        ];
        return cards.isEmpty() ? 0 : cards[0].Available_Limit__c;
    }
}