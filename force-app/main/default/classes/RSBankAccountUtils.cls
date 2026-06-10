// Utility class for banking customer queries
public with sharing class RSBankAccountUtils {
    
    // Get customer summary for agent responses
    public static Map<String, Object> getCustomerSummary(String email, String phone, String accountNumber) {
        RS_Bank_Account__c bankAccount = BankingProspectService.findExistingBankAccount(email, phone, accountNumber);
        System.debug('inside RSBankAccountUtils bankAccount--'+bankAccount);
        Map<String, Object> summary = new Map<String, Object>();
        
        if (bankAccount != null) {
            summary.put('isExistingCustomer', true);
            summary.put('accountNumber', bankAccount.Account_Number__c);
            summary.put('accountType', bankAccount.Account_Type__c);
            summary.put('balance', bankAccount.Balance__c);
            summary.put('existingProducts', BankingProspectService.getCustomerExistingProducts(bankAccount.Id));
        } else {
            summary.put('isExistingCustomer', false);
        }
        
        return summary;
    }
    
    @InvocableMethod(label='Get Customer Banking Summary' description='Gets existing customer information from RS_Bank_Account__c for agent responses, including balance and existing products.')
    public static List<CustomerSummaryResult> getCustomerBankingSummary(List<CustomerSummaryRequest> requests) {
        List<CustomerSummaryResult> results = new List<CustomerSummaryResult>();
        
        for (CustomerSummaryRequest request : requests) {
            CustomerSummaryResult result = new CustomerSummaryResult();
            Map<String, Object> summary = getCustomerSummary(request.email, request.phone, request.accountNumber);
            
            result.isExistingCustomer = (Boolean) summary.get('isExistingCustomer');
            if (result.isExistingCustomer) {
                result.accountNumber = (String) summary.get('accountNumber');
                result.accountType = (String) summary.get('accountType');
                result.balance = (Decimal) summary.get('balance');
                result.existingProducts = String.join((List<String>) summary.get('existingProducts'), ', ');
            }
            
            results.add(result);
        }
        
        return results;
    }
    
    public class CustomerSummaryRequest {
        @InvocableVariable(required=false)
        public String email;
        
        @InvocableVariable(required=false)
        public String phone;
        
        @InvocableVariable(required=false)
        public String accountNumber;
    }
    
    public class CustomerSummaryResult {
        @InvocableVariable
        public Boolean isExistingCustomer;
        
        @InvocableVariable
        public String accountNumber;
        
        @InvocableVariable
        public String accountType;
        
        @InvocableVariable
        public Decimal balance;
        
        @InvocableVariable
        public String existingProducts;
    }
}