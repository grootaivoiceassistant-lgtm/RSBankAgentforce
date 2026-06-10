public with sharing class AgentforceUserService {

    @InvocableMethod(label='Create Salesforce User')
    public static List<String> createUser(List<UserRequest> requests) {

        List<String> results = new List<String>();
	
        for(UserRequest req : requests){

            Profile profileRec = new Profile();
            profileRec = [SELECT Id FROM Profile WHERE Name = :req.profileName LIMIT 1];

            User u = new User();
            u.FirstName = req.firstName;
            u.LastName = req.lastName;
            u.Email = req.email;
            u.Username = req.username;
            u.Alias = req.alias;
            u.TimeZoneSidKey = 'Asia/Kolkata';
            u.LocaleSidKey = 'en_US';
            u.EmailEncodingKey = 'UTF-8';
            u.LanguageLocaleKey = 'en_US';
            u.ProfileId = profileRec.Id;

            insert u;

            results.add('User Created : ' + u.Id);
        }

        return results;
    }

    public class UserRequest {
        @InvocableVariable(required=true)
        public String firstName;

        @InvocableVariable(required=true)
        public String lastName;

        @InvocableVariable(required=true)
        public String email;

        @InvocableVariable(required=true)
        public String username;

        @InvocableVariable(required=true)
        public String alias;

        @InvocableVariable(required=true)
        public String profileName;
    }
}