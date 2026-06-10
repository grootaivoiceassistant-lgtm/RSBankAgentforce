// Invocable method class for Flow/Agentforce integration
public with sharing class BankingProspectFlowActions {
    
    @InvocableMethod(label='Create Banking Lead or Opportunity from RS Bank Account' 
                     description='Creates a Lead for new prospects or an Opportunity for existing customers based on interest in account opening, loans, credit cards, etc., using RS_Bank_Account__c lookup.')
    public static List<ProspectResult> createBankingProspect(List<ProspectRequest> requests) {
        List<ProspectResult> results = new List<ProspectResult>();
        
        // Prepare bulk requests for leads and opportunities
        List<BankingProspectService.BankingLeadRequest> leadRequests = new List<BankingProspectService.BankingLeadRequest>();
        List<BankingProspectService.BankingOpportunityRequest> oppRequests = new List<BankingProspectService.BankingOpportunityRequest>();
        
        for (ProspectRequest request : requests) {
            try {
                // Check if customer exists in RS_Bank_Account__c
                RS_Bank_Account__c existingBankAccount = BankingProspectService.findExistingBankAccount(
                    request.email, request.phone, request.accountNumber);
                
                BankingProspectService.InterestType interestType = 
                    getInterestType(request.interestType);
                
                if (existingBankAccount != null) {
                    // Prepare for bulk opportunity creation
                    BankingProspectService.BankingOpportunityRequest oppReq = new BankingProspectService.BankingOpportunityRequest();
                    oppReq.bankAccount = existingBankAccount;
                    oppReq.interestType = interestType;
                    oppReq.details = request.details;
                    oppReq.estimatedAmount = request.estimatedAmount;
                    oppRequests.add(oppReq);
                } else {
                    // Prepare for bulk lead creation
                    BankingProspectService.BankingLeadRequest leadReq = new BankingProspectService.BankingLeadRequest();
                    leadReq.firstName = request.firstName;
                    leadReq.lastName = request.lastName;
                    leadReq.email = request.email;
                    leadReq.phone = request.phone;
                    leadReq.interestType = interestType;
                    leadReq.details = request.details;
                    leadRequests.add(leadReq);
                }
            } catch (Exception e) {
                ProspectResult result = new ProspectResult();
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
                results.add(result);
            }
        }
        
        // Bulk create leads
        if (!leadRequests.isEmpty()) {
            List<Lead> createdLeads = BankingProspectService.createBankingLeads(leadRequests);
            for (Lead lead : createdLeads) {
                ProspectResult result = new ProspectResult();
                result.recordId = lead.Id;
                result.recordType = 'Lead';
                result.success = true;
                result.message = 'Lead created for new prospect';
                results.add(result);
            }
        }
        
        // Bulk create opportunities
        if (!oppRequests.isEmpty()) {
            List<Opportunity> createdOpps = BankingProspectService.createBankingOpportunities(oppRequests);
            for (Integer i = 0; i < createdOpps.size(); i++) {
                Opportunity opp = createdOpps[i];
                BankingProspectService.BankingOpportunityRequest oppReq = oppRequests[i];
                List<String> existingProducts = BankingProspectService.getCustomerExistingProducts(oppReq.bankAccount.Id);
                ProspectResult result = new ProspectResult();
                result.recordId = opp.Id;
                result.recordType = 'Opportunity';
                result.success = true;
                result.message = 'Opportunity created for existing customer (Account: ' + oppReq.bankAccount.Account_Number__c + ')';
                result.customerAccountNumber = oppReq.bankAccount.Account_Number__c;
                result.existingProducts = String.join(existingProducts, ', ');
                results.add(result);
            }
        }
        
        return results;
    }
    
    private static BankingProspectService.InterestType getInterestType(String interestString) {
        if (String.isBlank(interestString)) {
            return BankingProspectService.InterestType.OTHER;
        }
        switch on interestString.toLowerCase() {
            when 'account', 'account opening', 'savings', 'checking', 'current', 'fixed deposit' {
                return BankingProspectService.InterestType.ACCOUNT_OPENING;
            }
            when 'loan', 'mortgage', 'personal loan', 'auto loan', 'home loan', 'business loan' {
                return BankingProspectService.InterestType.LOAN;
            }
            when 'credit card', 'card', 'debit card' {
                return BankingProspectService.InterestType.CREDIT_CARD;
            }
            when 'investment', 'investing', 'wealth management', 'mutual funds', 'sip' {
                return BankingProspectService.InterestType.INVESTMENT;
            }
            when else {
                return BankingProspectService.InterestType.OTHER;
            }
        }
    }
    
    // Input class for the invocable method
    public class ProspectRequest {
        @InvocableVariable(description='Customer first name')
        public String firstName;
        
        @InvocableVariable( description='Customer last name')
        public String lastName;
        
        @InvocableVariable( description='Customer email address')
        public String email;
        
        @InvocableVariable( description='Customer phone number')
        public String phone;
        
        @InvocableVariable( description='Existing account number if known')
        public String accountNumber;
        
        @InvocableVariable(required=true)
        public String interestType;
        
        @InvocableVariable( description='Additional details about customer interest')
        public String details;
        
        @InvocableVariable( description='Estimated amount for loans/investments')
        public Decimal estimatedAmount;
    }
    
    // Output class for the invocable method
    public class ProspectResult {
        @InvocableVariable(description='ID of created Lead or Opportunity record')
        public String recordId;
        
        @InvocableVariable(description='Type of record created (Lead or Opportunity)')
        public String recordType;
        
        @InvocableVariable(description='Whether the operation was successful')
        public Boolean success;
        
        @InvocableVariable(description='Success or error message')
        public String message;
        
        @InvocableVariable(description='Customer account number if existing customer')
        public String customerAccountNumber;
        
        @InvocableVariable(description='List of existing products customer already has')
        public String existingProducts;
    }
}