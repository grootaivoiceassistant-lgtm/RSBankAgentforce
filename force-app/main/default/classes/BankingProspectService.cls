// Main service class for creating banking prospects using RS_Bank_Account__c
public with sharing class BankingProspectService {
    
    public enum InterestType {
        ACCOUNT_OPENING,
        LOAN,
        CREDIT_CARD,
        INVESTMENT,
        OTHER
    }
    
    // Method to create Leads for new prospects (bulkified)
    public static List<Lead> createBankingLeads(List<BankingLeadRequest> requests) {
        List<Lead> leadsToInsert = new List<Lead>();
        
        for (BankingLeadRequest request : requests) {
            if (String.isBlank(request.lastName)) {
                throw new BankingProspectException('Last name is required for creating a Lead');
            }
            
            Lead newLead = new Lead();
            newLead.FirstName = request.firstName;
            newLead.LastName = request.lastName;
            newLead.Email = request.email;
            newLead.Phone = request.phone;
            newLead.Company = request.lastName + ' Household'; // Required field for Lead
            newLead.Status = 'New';
            newLead.LeadSource = 'Agentforce Chat';
            
            // Set industry and lead source based on interest type
            switch on request.interestType {
                when ACCOUNT_OPENING {
                    newLead.Industry = 'Banking - Account Services';
                    newLead.Description = 'Customer interested in opening a new bank account. Details: ' + request.details;
                }
                when LOAN {
                    newLead.Industry = 'Banking - Lending';
                    newLead.Description = 'Customer interested in loan products. Details: ' + request.details;
                }
                when CREDIT_CARD {
                    newLead.Industry = 'Banking - Credit Cards';
                    newLead.Description = 'Customer interested in credit card products. Details: ' + request.details;
                }
                when INVESTMENT {
                    newLead.Industry = 'Banking - Investment';
                    newLead.Description = 'Customer interested in investment products. Details: ' + request.details;
                }
                when OTHER {
                    newLead.Industry = 'Banking - General';
                    newLead.Description = 'Customer inquiry: ' + request.details;
                }
            }
            
            leadsToInsert.add(newLead);
        }
        
        try {
            Database.insert(leadsToInsert, false); // Allow partial success
            System.debug('Leads created successfully');
            return leadsToInsert;
        } catch (DmlException e) {
            System.debug('Error creating leads: ' + e.getMessage());
            throw new BankingProspectException('Failed to create leads: ' + e.getMessage());
        }
    }
    
    // Wrapper class for bulk lead creation requests
    public class BankingLeadRequest {
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
        public InterestType interestType;
        public String details;
    }
    
    // Method to create Opportunities for existing RS Bank Account customers (bulkified)
    public static List<Opportunity> createBankingOpportunities(List<BankingOpportunityRequest> requests) {
        List<Opportunity> oppsToInsert = new List<Opportunity>();
        
        for (BankingOpportunityRequest request : requests) {
            RS_Bank_Account__c bankAccount = request.bankAccount;
            Opportunity newOpp = new Opportunity();
            
            // Link to Account if available
            if (bankAccount.Account_Holder__c != null) {
                newOpp.AccountId = bankAccount.Account_Holder__c;
            }
            
            // Link to Contact if available
            if (bankAccount.Contact__c != null) {
                newOpp.ContactId = bankAccount.Contact__c;
            }
            
            newOpp.CloseDate = Date.today().addDays(30); // Default 30 days out
            newOpp.StageName = 'Prospecting';
            newOpp.LeadSource = 'Agentforce Chat';
            
            // Add custom field to link back to the bank account if you have one
            // newOpp.RS_Bank_Account__c = bankAccount.Id; // Uncomment if you add this lookup field
            
            String holderName = bankAccount.Account_Holder__c != null ? bankAccount.Account_Holder__c : 'Unknown Customer';
            String accountNumber = bankAccount.Account_Number__c != null ? bankAccount.Account_Number__c : 'Unknown';
            
            // Set opportunity details based on interest type
            switch on request.interestType {
                when ACCOUNT_OPENING {
                    newOpp.Name = holderName + ' - New Account Opening';
                    newOpp.Type = 'New Customer';
                    newOpp.Description = 'Existing customer (Account: ' + accountNumber + 
                                       ') interested in opening additional account: ' + request.details;
                    newOpp.Amount = request.estimatedAmount != null ? request.estimatedAmount : 1000;
                }
                when LOAN {
                    newOpp.Name = holderName + ' - Loan Application';
                    newOpp.Type = 'Loan';
                    newOpp.Description = 'Existing customer (Account: ' + accountNumber + 
                                       ') interested in loan products: ' + request.details;
                    newOpp.Amount = request.estimatedAmount;
                }
                when CREDIT_CARD {
                    newOpp.Name = holderName + ' - Credit Card Application';
                    newOpp.Type = 'Credit Card';
                    newOpp.Description = 'Existing customer (Account: ' + accountNumber + 
                                       ') interested in credit card: ' + request.details;
                    newOpp.Amount = request.estimatedAmount != null ? request.estimatedAmount : 5000;
                }
                when INVESTMENT {
                    newOpp.Name = holderName + ' - Investment Opportunity';
                    newOpp.Type = 'Investment';
                    newOpp.Description = 'Existing customer (Account: ' + accountNumber + 
                                       ') interested in investment products: ' + request.details;
                    newOpp.Amount = request.estimatedAmount;
                }
                when OTHER {
                    newOpp.Name = holderName + ' - Banking Opportunity';
                    newOpp.Type = 'Other';
                    newOpp.Description = 'Existing customer (Account: ' + accountNumber + 
                                       ') inquiry: ' + request.details;
                    newOpp.Amount = request.estimatedAmount;
                }
            }
            
            oppsToInsert.add(newOpp);
        }
        
        try {
            Database.insert(oppsToInsert, false); // Allow partial success
            System.debug('Opportunities created successfully');
            return oppsToInsert;
        } catch (DmlException e) {
            System.debug('Error creating opportunities: ' + e.getMessage());
            throw new BankingProspectException('Failed to create opportunities: ' + e.getMessage());
        }
    }
    
    // Wrapper class for bulk opportunity creation requests
    public class BankingOpportunityRequest {
        public RS_Bank_Account__c bankAccount;
        public InterestType interestType;
        public String details;
        public Decimal estimatedAmount;
    }
    
    // Method to find existing customer by email, phone, or account number
    public static RS_Bank_Account__c findExistingBankAccount(String email, String phone, String accountNumber) {
        List<RS_Bank_Account__c> bankAccounts = new List<RS_Bank_Account__c>();
        
        String query = 'SELECT Id, Account_Holder__c, Contact__c, Account_Number__c, ' +
                       'Customer_Email__c, Customer_Phone__c, Account_Type__c, Balance__c ' +
                       'FROM RS_Bank_Account__c WHERE ';
        
        List<String> conditions = new List<String>();
        if (String.isNotBlank(accountNumber)) {
            conditions.add('Account_Number__c = :accountNumber');
        }
        if (String.isNotBlank(email)) {
            conditions.add('Customer_Email__c = :email');
        }
        if (String.isNotBlank(phone)) {
            conditions.add('Customer_Phone__c = :phone');
        }
        
        if (conditions.isEmpty()) {
            return null;
        }
        
        query += String.join(conditions, ' OR ');
        query += ' WITH SECURITY_ENFORCED LIMIT 1';
        
        bankAccounts = Database.query(query);
        System.debug('bankAccounts--'+bankAccounts);
        
        return bankAccounts.isEmpty() ? null : bankAccounts[0];
    }
    
    // Method to get customer's existing products (for cross-selling)
    public static List<String> getCustomerExistingProducts(Id bankAccountId) {
        List<String> existingProducts = new List<String>();
        
        // Get the base account to extract customer email
        RS_Bank_Account__c baseAccount = [SELECT Customer_Email__c FROM RS_Bank_Account__c WHERE Id = :bankAccountId WITH SECURITY_ENFORCED LIMIT 1];
        if (baseAccount != null && String.isNotBlank(baseAccount.Customer_Email__c)) {
            // Query all accounts for the same customer email
            List<RS_Bank_Account__c> accounts = [SELECT Account_Type__c FROM RS_Bank_Account__c 
                                                 WHERE Customer_Email__c = :baseAccount.Customer_Email__c 
                                                 WITH SECURITY_ENFORCED];
            
            for (RS_Bank_Account__c acc : accounts) {
                if (String.isNotBlank(acc.Account_Type__c)) {
                    existingProducts.add(acc.Account_Type__c);
                }
            }
        }
        
        // Check for existing loans if object exists
        if (Schema.getGlobalDescribe().containsKey('Loan__c')) {
            try {
                List<Loan__c> loans = Database.query('SELECT Id FROM Loan__c WHERE RS_Bank_Account__c = :bankAccountId WITH SECURITY_ENFORCED');
                if (!loans.isEmpty()) {
                    existingProducts.add('Loan');
                }
            } catch (Exception e) {
                System.debug('Could not query Loan__c: ' + e.getMessage());
            }
        }
        
        // Check for existing cards if object exists
        if (Schema.getGlobalDescribe().containsKey('Card__c')) {
            try {
                List<Card__c> cards = Database.query('SELECT Id FROM Card__c WHERE RS_Bank_Account__c = :bankAccountId WITH SECURITY_ENFORCED');
                if (!cards.isEmpty()) {
                    existingProducts.add('Credit Card');
                }
            } catch (Exception e) {
                System.debug('Could not query Card__c: ' + e.getMessage());
            }
        }
        
        return existingProducts;
    }
    
    // Custom exception class
    public class BankingProspectException extends Exception {}
}