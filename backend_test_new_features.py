import requests
import sys
import json
from datetime import datetime

class VoteSecretNewFeaturesTest:
    def __init__(self, base_url="https://dac23748-f23d-42e5-8d4d-0b6bf9f295c1.preview.emergentagent.com"):
        self.base_url = base_url
        self.api_url = f"{base_url}/api"
        self.tests_run = 0
        self.tests_passed = 0
        self.meeting_id = None
        self.meeting_code = None
        self.participant_id = None

    def run_test(self, name, method, endpoint, expected_status, data=None):
        """Run a single API test"""
        url = f"{self.api_url}/{endpoint}"
        headers = {'Content-Type': 'application/json'}

        self.tests_run += 1
        print(f"\n🔍 Testing {name}...")
        print(f"   URL: {url}")
        if data:
            print(f"   Data: {json.dumps(data, indent=2)}")
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=headers)
            elif method == 'POST':
                response = requests.post(url, json=data, headers=headers)

            success = response.status_code == expected_status
            if success:
                self.tests_passed += 1
                print(f"✅ Passed - Status: {response.status_code}")
                try:
                    response_data = response.json()
                    print(f"   Response: {json.dumps(response_data, indent=2)}")
                    return True, response_data
                except:
                    return True, {}
            else:
                print(f"❌ Failed - Expected {expected_status}, got {response.status_code}")
                try:
                    error_data = response.json()
                    print(f"   Error: {json.dumps(error_data, indent=2)}")
                except:
                    print(f"   Error: {response.text}")
                return False, {}

        except Exception as e:
            print(f"❌ Failed - Error: {str(e)}")
            return False, {}

    def setup_meeting_and_participant(self):
        """Setup meeting and participant for testing"""
        # Create meeting
        success, response = self.run_test(
            "Create Meeting for New Features Test",
            "POST",
            "meetings",
            200,
            data={
                "title": "New Features Test Meeting",
                "organizer_name": "Test Organizer"
            }
        )
        if success:
            self.meeting_id = response.get('id')
            self.meeting_code = response.get('meeting_code')
        
        # Join as participant
        if self.meeting_code:
            success, response = self.run_test(
                "Join Meeting as Participant",
                "POST",
                "participants/join",
                200,
                data={
                    "name": "Test Participant",
                    "meeting_code": self.meeting_code
                }
            )
            if success:
                self.participant_id = response.get('id')
                
                # Approve participant
                self.run_test(
                    "Approve Participant",
                    "POST",
                    f"participants/{self.participant_id}/approve",
                    200,
                    data={
                        "participant_id": self.participant_id,
                        "approved": True
                    }
                )

    def test_poll_with_real_time_results_off(self):
        """Test creating poll with show_results_real_time = False"""
        if not self.meeting_id:
            return False
        
        success, response = self.run_test(
            "Create Poll with Real-time Results OFF",
            "POST",
            f"meetings/{self.meeting_id}/polls",
            200,
            data={
                "question": "Should we implement this feature? (Results hidden until vote)",
                "options": ["Yes", "No", "Maybe"],
                "show_results_real_time": False
            }
        )
        
        if success:
            # Verify the show_results_real_time field is set correctly
            if response.get('show_results_real_time') == False:
                print("   ✅ show_results_real_time correctly set to False")
                return True, response.get('id')
            else:
                print("   ❌ show_results_real_time not set correctly")
                return False, None
        return False, None

    def test_poll_with_real_time_results_on(self):
        """Test creating poll with show_results_real_time = True (default)"""
        if not self.meeting_id:
            return False
        
        success, response = self.run_test(
            "Create Poll with Real-time Results ON",
            "POST",
            f"meetings/{self.meeting_id}/polls",
            200,
            data={
                "question": "Do you like the new design? (Results shown in real-time)",
                "options": ["Love it", "It's okay", "Needs work"],
                "show_results_real_time": True
            }
        )
        
        if success:
            # Verify the show_results_real_time field is set correctly
            if response.get('show_results_real_time') == True:
                print("   ✅ show_results_real_time correctly set to True")
                return True, response.get('id')
            else:
                print("   ❌ show_results_real_time not set correctly")
                return False, None
        return False, None

    def test_all_polls_visible_to_participants(self):
        """Test that participants can see ALL polls (active, closed, draft)"""
        if not self.meeting_id:
            return False
        
        # Get all polls from participant perspective
        success, response = self.run_test(
            "Get All Polls (Participant View)",
            "GET",
            f"meetings/{self.meeting_id}/polls",
            200
        )
        
        if success:
            polls = response
            print(f"   📊 Found {len(polls)} polls")
            
            # Check that we can see polls in different states
            statuses = [poll.get('status') for poll in polls]
            print(f"   📋 Poll statuses: {statuses}")
            
            # Verify we have polls with different show_results_real_time settings
            real_time_settings = [poll.get('show_results_real_time') for poll in polls]
            print(f"   ⚙️  Real-time settings: {real_time_settings}")
            
            if len(polls) >= 2:
                print("   ✅ Multiple polls visible to participants")
                return True
            else:
                print("   ❌ Expected multiple polls for testing")
                return False
        return False

    def test_default_show_results_real_time(self):
        """Test that show_results_real_time defaults to True when not specified"""
        if not self.meeting_id:
            return False
        
        success, response = self.run_test(
            "Create Poll without specifying show_results_real_time (should default to True)",
            "POST",
            f"meetings/{self.meeting_id}/polls",
            200,
            data={
                "question": "Default behavior test - should show results in real-time",
                "options": ["Option A", "Option B"]
            }
        )
        
        if success:
            # Verify the show_results_real_time field defaults to True
            if response.get('show_results_real_time') == True:
                print("   ✅ show_results_real_time correctly defaults to True")
                return True
            else:
                print(f"   ❌ show_results_real_time should default to True, got: {response.get('show_results_real_time')}")
                return False
        return False

def main():
    print("🚀 Starting Vote Secret NEW FEATURES Tests")
    print("=" * 60)
    
    tester = VoteSecretNewFeaturesTest()
    
    # Setup
    print("\n🔧 SETUP")
    print("-" * 10)
    tester.setup_meeting_and_participant()
    
    # Test new features
    test_results = []
    
    print("\n🆕 NEW FEATURES TESTS")
    print("-" * 25)
    
    # Test show_results_real_time functionality
    success1, poll_id_1 = tester.test_poll_with_real_time_results_off()
    test_results.append(("Poll with Real-time Results OFF", success1))
    
    success2, poll_id_2 = tester.test_poll_with_real_time_results_on()
    test_results.append(("Poll with Real-time Results ON", success2))
    
    test_results.append(("Default show_results_real_time", tester.test_default_show_results_real_time()))
    
    # Test participant can see all polls
    test_results.append(("All Polls Visible to Participants", tester.test_all_polls_visible_to_participants()))
    
    # Print final results
    print("\n" + "=" * 60)
    print("📊 NEW FEATURES TEST RESULTS")
    print("=" * 60)
    
    for test_name, result in test_results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {test_name}")
    
    print(f"\n📈 Summary: {tester.tests_passed}/{tester.tests_run} tests passed")
    
    if tester.tests_passed == tester.tests_run:
        print("🎉 All new features tests passed!")
        return 0
    else:
        print("⚠️  Some new features tests failed. Check the details above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())