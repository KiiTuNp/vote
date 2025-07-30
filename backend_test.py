import requests
import sys
import json
from datetime import datetime
import time

class VoteSecretAPITester:
    def __init__(self, base_url="https://1e442c2f-de01-4622-93eb-720aff0317aa.preview.emergentagent.com"):
        self.base_url = base_url
        self.api_url = f"{base_url}/api"
        self.tests_run = 0
        self.tests_passed = 0
        self.meeting_id = None
        self.meeting_code = None
        self.participant_id = None
        self.poll_id = None

    def run_test(self, name, method, endpoint, expected_status, data=None, headers=None):
        """Run a single API test"""
        url = f"{self.api_url}/{endpoint}"
        if headers is None:
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
            elif method == 'PUT':
                response = requests.put(url, json=data, headers=headers)
            elif method == 'DELETE':
                response = requests.delete(url, headers=headers)

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

    def test_create_meeting(self):
        """Test creating a meeting"""
        success, response = self.run_test(
            "Create Meeting",
            "POST",
            "meetings",
            200,
            data={
                "title": "Test Assembly 2025",
                "organizer_name": "Test Organizer"
            }
        )
        if success:
            self.meeting_id = response.get('id')
            self.meeting_code = response.get('meeting_code')
            print(f"   Meeting ID: {self.meeting_id}")
            print(f"   Meeting Code: {self.meeting_code}")
        return success

    def test_get_meeting_by_code(self):
        """Test getting meeting by code"""
        if not self.meeting_code:
            print("❌ Skipping - No meeting code available")
            return False
        
        success, response = self.run_test(
            "Get Meeting by Code",
            "GET",
            f"meetings/{self.meeting_code}",
            200
        )
        return success

    def test_join_meeting(self):
        """Test participant joining meeting"""
        if not self.meeting_code:
            print("❌ Skipping - No meeting code available")
            return False
        
        success, response = self.run_test(
            "Join Meeting",
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
            print(f"   Participant ID: {self.participant_id}")
        return success

    def test_duplicate_participant_name(self):
        """Test joining with duplicate name (should fail)"""
        if not self.meeting_code:
            print("❌ Skipping - No meeting code available")
            return False
        
        success, response = self.run_test(
            "Join Meeting with Duplicate Name (should fail)",
            "POST",
            "participants/join",
            400,  # Should fail with 400
            data={
                "name": "Test Participant",  # Same name as before
                "meeting_code": self.meeting_code
            }
        )
        return success

    def test_join_invalid_meeting(self):
        """Test joining invalid meeting (should fail)"""
        success, response = self.run_test(
            "Join Invalid Meeting (should fail)",
            "POST",
            "participants/join",
            404,  # Should fail with 404
            data={
                "name": "Test Participant 2",
                "meeting_code": "INVALID123"
            }
        )
        return success

    def test_get_participant_status(self):
        """Test getting participant status"""
        if not self.participant_id:
            print("❌ Skipping - No participant ID available")
            return False
        
        success, response = self.run_test(
            "Get Participant Status",
            "GET",
            f"participants/{self.participant_id}/status",
            200
        )
        return success

    def test_approve_participant(self):
        """Test approving participant"""
        if not self.participant_id:
            print("❌ Skipping - No participant ID available")
            return False
        
        success, response = self.run_test(
            "Approve Participant",
            "POST",
            f"participants/{self.participant_id}/approve",
            200,
            data={
                "participant_id": self.participant_id,
                "approved": True
            }
        )
        return success

    def test_get_organizer_view(self):
        """Test getting organizer view"""
        if not self.meeting_id:
            print("❌ Skipping - No meeting ID available")
            return False
        
        success, response = self.run_test(
            "Get Organizer View",
            "GET",
            f"meetings/{self.meeting_id}/organizer",
            200
        )
        return success

    def test_create_poll(self):
        """Test creating a poll"""
        if not self.meeting_id:
            print("❌ Skipping - No meeting ID available")
            return False
        
        success, response = self.run_test(
            "Create Poll",
            "POST",
            f"meetings/{self.meeting_id}/polls",
            200,
            data={
                "question": "Do you approve this test proposal?",
                "options": ["Yes", "No", "Abstain"],
                "timer_duration": 60
            }
        )
        if success:
            self.poll_id = response.get('id')
            print(f"   Poll ID: {self.poll_id}")
        return success

    def test_get_meeting_polls(self):
        """Test getting meeting polls"""
        if not self.meeting_id:
            print("❌ Skipping - No meeting ID available")
            return False
        
        success, response = self.run_test(
            "Get Meeting Polls",
            "GET",
            f"meetings/{self.meeting_id}/polls",
            200
        )
        return success

    def test_start_poll(self):
        """Test starting a poll"""
        if not self.poll_id:
            print("❌ Skipping - No poll ID available")
            return False
        
        success, response = self.run_test(
            "Start Poll",
            "POST",
            f"polls/{self.poll_id}/start",
            200
        )
        return success

    def test_submit_vote(self):
        """Test submitting a vote"""
        if not self.poll_id:
            print("❌ Skipping - No poll ID available")
            return False
        
        # First get poll details to get option IDs
        poll_response = requests.get(f"{self.api_url}/meetings/{self.meeting_id}/polls")
        if poll_response.status_code == 200:
            polls = poll_response.json()
            if polls:
                poll = polls[0]  # Get first poll
                if poll['options']:
                    option_id = poll['options'][0]['id']  # Get first option
                    
                    success, response = self.run_test(
                        "Submit Vote",
                        "POST",
                        "votes",
                        200,
                        data={
                            "poll_id": self.poll_id,
                            "option_id": option_id
                        }
                    )
                    return success
        
        print("❌ Could not get poll options for voting")
        return False

    def test_vote_on_inactive_poll(self):
        """Test voting on inactive poll (should fail)"""
        if not self.poll_id:
            print("❌ Skipping - No poll ID available")
            return False
        
        # First close the poll
        requests.post(f"{self.api_url}/polls/{self.poll_id}/close")
        
        # Try to vote on closed poll
        poll_response = requests.get(f"{self.api_url}/meetings/{self.meeting_id}/polls")
        if poll_response.status_code == 200:
            polls = poll_response.json()
            if polls:
                poll = polls[0]
                if poll['options']:
                    option_id = poll['options'][0]['id']
                    
                    success, response = self.run_test(
                        "Vote on Inactive Poll (should fail)",
                        "POST",
                        "votes",
                        400,  # Should fail
                        data={
                            "poll_id": self.poll_id,
                            "option_id": option_id
                        }
                    )
                    return success
        
        print("❌ Could not test voting on inactive poll")
        return False

    def test_get_poll_results(self):
        """Test getting poll results"""
        if not self.poll_id:
            print("❌ Skipping - No poll ID available")
            return False
        
        success, response = self.run_test(
            "Get Poll Results",
            "GET",
            f"polls/{self.poll_id}/results",
            200
        )
        return success

    def test_close_poll(self):
        """Test closing a poll"""
        if not self.poll_id:
            print("❌ Skipping - No poll ID available")
            return False
        
        success, response = self.run_test(
            "Close Poll",
            "POST",
            f"polls/{self.poll_id}/close",
            200
        )
        return success

    def test_generate_report_and_cleanup(self):
        """Test PDF report generation and data cleanup"""
        if not self.meeting_id:
            print("❌ Skipping - No meeting ID available")
            return False
        
        print(f"\n🔍 Testing PDF Report Generation and Data Cleanup...")
        print(f"   Meeting ID: {self.meeting_id}")
        
        # Test PDF report generation (this should return a file)
        url = f"{self.api_url}/meetings/{self.meeting_id}/report"
        print(f"   URL: {url}")
        
        try:
            response = requests.get(url)
            success = response.status_code == 200
            
            if success:
                self.tests_passed += 1
                print(f"✅ Passed - Status: {response.status_code}")
                print(f"   Content-Type: {response.headers.get('content-type', 'N/A')}")
                print(f"   Content-Length: {len(response.content)} bytes")
                
                # Verify it's a PDF
                if response.headers.get('content-type') == 'application/pdf':
                    print("   ✅ PDF file generated successfully")
                else:
                    print("   ⚠️  Warning: Content type is not application/pdf")
                
                # Now test that all data has been deleted
                print("\n   🧹 Testing Data Cleanup...")
                
                # Test 1: Meeting should be deleted (404)
                meeting_response = requests.get(f"{self.api_url}/meetings/{self.meeting_code}")
                if meeting_response.status_code == 404:
                    print("   ✅ Meeting deleted successfully")
                else:
                    print(f"   ❌ Meeting still exists (Status: {meeting_response.status_code})")
                
                # Test 2: Organizer view should return 404
                organizer_response = requests.get(f"{self.api_url}/meetings/{self.meeting_id}/organizer")
                if organizer_response.status_code == 404:
                    print("   ✅ Organizer view returns 404 (meeting deleted)")
                else:
                    print(f"   ❌ Organizer view still accessible (Status: {organizer_response.status_code})")
                
                # Test 3: Participant status should return 404
                if self.participant_id:
                    participant_response = requests.get(f"{self.api_url}/participants/{self.participant_id}/status")
                    if participant_response.status_code == 404:
                        print("   ✅ Participant data deleted successfully")
                    else:
                        print(f"   ❌ Participant data still exists (Status: {participant_response.status_code})")
                
                # Test 4: Poll results should return 404
                if self.poll_id:
                    poll_response = requests.get(f"{self.api_url}/polls/{self.poll_id}/results")
                    if poll_response.status_code == 404:
                        print("   ✅ Poll data deleted successfully")
                    else:
                        print(f"   ❌ Poll data still exists (Status: {poll_response.status_code})")
                
                return True
            else:
                print(f"❌ Failed - Expected 200, got {response.status_code}")
                try:
                    error_data = response.json()
                    print(f"   Error: {json.dumps(error_data, indent=2)}")
                except:
                    print(f"   Error: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Failed - Error: {str(e)}")
            return False

def main():
    print("🚀 Starting Vote Secret API Tests")
    print("=" * 50)
    
    tester = VoteSecretAPITester()
    
    # Test sequence following the user flow
    test_results = []
    
    # 1. Meeting Management Tests
    print("\n📋 MEETING MANAGEMENT TESTS")
    print("-" * 30)
    test_results.append(("Create Meeting", tester.test_create_meeting()))
    test_results.append(("Get Meeting by Code", tester.test_get_meeting_by_code()))
    
    # 2. Participant Management Tests
    print("\n👥 PARTICIPANT MANAGEMENT TESTS")
    print("-" * 35)
    test_results.append(("Join Meeting", tester.test_join_meeting()))
    test_results.append(("Duplicate Name (should fail)", tester.test_duplicate_participant_name()))
    test_results.append(("Invalid Meeting (should fail)", tester.test_join_invalid_meeting()))
    test_results.append(("Get Participant Status", tester.test_get_participant_status()))
    test_results.append(("Approve Participant", tester.test_approve_participant()))
    test_results.append(("Get Organizer View", tester.test_get_organizer_view()))
    
    # 3. Poll Management Tests
    print("\n🗳️  POLL MANAGEMENT TESTS")
    print("-" * 25)
    test_results.append(("Create Poll", tester.test_create_poll()))
    test_results.append(("Get Meeting Polls", tester.test_get_meeting_polls()))
    test_results.append(("Start Poll", tester.test_start_poll()))
    
    # 4. Voting Tests
    print("\n✅ VOTING TESTS")
    print("-" * 15)
    test_results.append(("Submit Vote", tester.test_submit_vote()))
    test_results.append(("Get Poll Results", tester.test_get_poll_results()))
    test_results.append(("Vote on Inactive Poll (should fail)", tester.test_vote_on_inactive_poll()))
    test_results.append(("Close Poll", tester.test_close_poll()))
    
    # 5. PDF Report and Data Cleanup Tests
    print("\n📄 PDF REPORT & DATA CLEANUP TESTS")
    print("-" * 35)
    test_results.append(("Generate Report & Cleanup", tester.test_generate_report_and_cleanup()))
    
    # Print final results
    print("\n" + "=" * 50)
    print("📊 FINAL TEST RESULTS")
    print("=" * 50)
    
    for test_name, result in test_results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {test_name}")
    
    print(f"\n📈 Summary: {tester.tests_passed}/{tester.tests_run} tests passed")
    
    if tester.tests_passed == tester.tests_run:
        print("🎉 All tests passed!")
        return 0
    else:
        print("⚠️  Some tests failed. Check the details above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())