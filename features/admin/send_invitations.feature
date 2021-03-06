@no-txn
@javascript
Feature: Send Invitations
  As the owner of the site
  I want to send invitations to visitors who have requested invitations
  so users can try the site

  Scenario: Administrator sends invitation
    Given I am not logged in
    When I visit the home page
    And I follow the first "Je veux le tester !"
    When I fill in "Email" with "example@example.com"
    And I click a button "Demande d'invitation"
    Then I should see a message "Merci"
    When I am logged in as an administrator
    And I visit the users page
    When I click a link "send invitation"
    Then I should see "resend"
    When I open the email with subject "Confirmation instructions"
    Then I should see "confirm your email address" in the email body
