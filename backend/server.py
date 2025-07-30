from fastapi import FastAPI, APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import uuid
from datetime import datetime
from enum import Enum
import json
import tempfile
from reportlab.lib.pagesizes import letter, A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# Create the main app without a prefix
app = FastAPI()

# Create a router with the /api prefix
api_router = APIRouter(prefix="/api")

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, meeting_id: str):
        await websocket.accept()
        if meeting_id not in self.active_connections:
            self.active_connections[meeting_id] = []
        self.active_connections[meeting_id].append(websocket)

    def disconnect(self, websocket: WebSocket, meeting_id: str):
        if meeting_id in self.active_connections:
            self.active_connections[meeting_id].remove(websocket)

    async def send_to_meeting(self, message: dict, meeting_id: str):
        if meeting_id in self.active_connections:
            for connection in self.active_connections[meeting_id]:
                try:
                    await connection.send_text(json.dumps(message))
                except:
                    pass

manager = ConnectionManager()

# Enums
class ParticipantStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved" 
    REJECTED = "rejected"

class PollStatus(str, Enum):
    DRAFT = "draft"
    ACTIVE = "active"
    CLOSED = "closed"

class MeetingStatus(str, Enum):
    ACTIVE = "active"
    COMPLETED = "completed"

# Models
class Meeting(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    title: str
    organizer_name: str
    meeting_code: str = Field(default_factory=lambda: str(uuid.uuid4())[:8].upper())
    status: MeetingStatus = MeetingStatus.ACTIVE
    created_at: datetime = Field(default_factory=datetime.utcnow)

class MeetingCreate(BaseModel):
    title: str
    organizer_name: str

class Participant(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    meeting_id: str
    approval_status: ParticipantStatus = ParticipantStatus.PENDING
    joined_at: datetime = Field(default_factory=datetime.utcnow)

class ParticipantJoin(BaseModel):
    name: str
    meeting_code: str

class ParticipantApproval(BaseModel):
    participant_id: str
    approved: bool

class PollOption(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    text: str
    votes: int = 0

class Poll(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    meeting_id: str
    question: str
    options: List[PollOption]
    status: PollStatus = PollStatus.DRAFT
    timer_duration: Optional[int] = None  # in seconds
    timer_started_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

class PollCreate(BaseModel):
    question: str
    options: List[str]
    timer_duration: Optional[int] = None

class Vote(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    poll_id: str
    option_id: str
    voted_at: datetime = Field(default_factory=datetime.utcnow)
    # Note: No participant_id to maintain anonymity

class VoteCreate(BaseModel):
    poll_id: str
    option_id: str

# Meeting endpoints
@api_router.post("/meetings", response_model=Meeting)
async def create_meeting(meeting_data: MeetingCreate):
    meeting = Meeting(**meeting_data.dict())
    await db.meetings.insert_one(meeting.dict())
    return meeting

@api_router.get("/meetings/{meeting_code}")
async def get_meeting_by_code(meeting_code: str):
    meeting = await db.meetings.find_one({"meeting_code": meeting_code, "status": "active"})
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    return Meeting(**meeting)

@api_router.get("/meetings/{meeting_id}/organizer")
async def get_meeting_organizer_view(meeting_id: str):
    meeting = await db.meetings.find_one({"id": meeting_id})
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    
    # Get participants
    participants = await db.participants.find({"meeting_id": meeting_id}).to_list(1000)
    
    # Get polls
    polls = await db.polls.find({"meeting_id": meeting_id}).to_list(1000)
    
    return {
        "meeting": Meeting(**meeting),
        "participants": [Participant(**p) for p in participants],
        "polls": [Poll(**poll) for poll in polls]
    }

# Participant endpoints
@api_router.post("/participants/join")
async def join_meeting(join_data: ParticipantJoin):
    # Check if meeting exists and is active
    meeting = await db.meetings.find_one({"meeting_code": join_data.meeting_code, "status": "active"})
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found or not active")
    
    # Check if participant name already exists in this meeting
    existing = await db.participants.find_one({
        "name": join_data.name, 
        "meeting_id": meeting["id"]
    })
    if existing:
        raise HTTPException(status_code=400, detail="Name already taken in this meeting")
    
    participant = Participant(name=join_data.name, meeting_id=meeting["id"])
    await db.participants.insert_one(participant.dict())
    
    # Notify organizer via WebSocket
    await manager.send_to_meeting({
        "type": "participant_joined",
        "participant": participant.dict()
    }, meeting["id"])
    
    return participant

@api_router.post("/participants/{participant_id}/approve")
async def approve_participant(participant_id: str, approval: ParticipantApproval):
    participant = await db.participants.find_one({"id": participant_id})
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")
    
    new_status = ParticipantStatus.APPROVED if approval.approved else ParticipantStatus.REJECTED
    await db.participants.update_one(
        {"id": participant_id},
        {"$set": {"approval_status": new_status}}
    )
    
    # Notify via WebSocket
    await manager.send_to_meeting({
        "type": "participant_approved",
        "participant_id": participant_id,
        "status": new_status
    }, participant["meeting_id"])
    
    return {"status": "success"}

@api_router.get("/participants/{participant_id}/status")
async def get_participant_status(participant_id: str):
    participant = await db.participants.find_one({"id": participant_id})
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")
    return {"status": participant["approval_status"]}

# Poll endpoints
@api_router.post("/meetings/{meeting_id}/polls", response_model=Poll)
async def create_poll(meeting_id: str, poll_data: PollCreate):
    # Verify meeting exists
    meeting = await db.meetings.find_one({"id": meeting_id})
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    
    options = [PollOption(text=opt) for opt in poll_data.options]
    poll = Poll(
        meeting_id=meeting_id,
        question=poll_data.question,
        options=options,
        timer_duration=poll_data.timer_duration
    )
    
    await db.polls.insert_one(poll.dict())
    return poll

@api_router.post("/polls/{poll_id}/start")
async def start_poll(poll_id: str):
    poll = await db.polls.find_one({"id": poll_id})
    if not poll:
        raise HTTPException(status_code=404, detail="Poll not found")
    
    update_data = {
        "status": PollStatus.ACTIVE,
        "timer_started_at": datetime.utcnow() if poll.get("timer_duration") else None
    }
    
    await db.polls.update_one({"id": poll_id}, {"$set": update_data})
    
    # Notify participants
    await manager.send_to_meeting({
        "type": "poll_started",
        "poll_id": poll_id
    }, poll["meeting_id"])
    
    return {"status": "started"}

@api_router.post("/polls/{poll_id}/close")
async def close_poll(poll_id: str):
    poll = await db.polls.find_one({"id": poll_id})
    if not poll:
        raise HTTPException(status_code=404, detail="Poll not found")
    
    await db.polls.update_one({"id": poll_id}, {"$set": {"status": PollStatus.CLOSED}})
    
    # Notify participants
    await manager.send_to_meeting({
        "type": "poll_closed",
        "poll_id": poll_id
    }, poll["meeting_id"])
    
    return {"status": "closed"}

@api_router.get("/meetings/{meeting_id}/polls")
async def get_meeting_polls(meeting_id: str):
    polls = await db.polls.find({"meeting_id": meeting_id}).to_list(1000)
    return [Poll(**poll) for poll in polls]

# Voting endpoints
@api_router.post("/votes")
async def submit_vote(vote_data: VoteCreate):
    # Verify poll exists and is active
    poll = await db.polls.find_one({"id": vote_data.poll_id})
    if not poll:
        raise HTTPException(status_code=404, detail="Poll not found")
    
    if poll["status"] != PollStatus.ACTIVE:
        raise HTTPException(status_code=400, detail="Poll is not active")
    
    # Check if option exists
    option_exists = any(opt["id"] == vote_data.option_id for opt in poll["options"])
    if not option_exists:
        raise HTTPException(status_code=400, detail="Invalid option")
    
    # Create anonymous vote
    vote = Vote(poll_id=vote_data.poll_id, option_id=vote_data.option_id)
    await db.votes.insert_one(vote.dict())
    
    # Update poll results
    await update_poll_results(vote_data.poll_id)
    
    # Notify real-time updates
    updated_poll = await db.polls.find_one({"id": vote_data.poll_id})
    await manager.send_to_meeting({
        "type": "vote_submitted",
        "poll": Poll(**updated_poll).dict()
    }, poll["meeting_id"])
    
    return {"status": "vote_submitted"}

async def update_poll_results(poll_id: str):
    # Get all votes for this poll
    votes = await db.votes.find({"poll_id": poll_id}).to_list(1000)
    vote_counts = {}
    
    for vote in votes:
        option_id = vote["option_id"]
        vote_counts[option_id] = vote_counts.get(option_id, 0) + 1
    
    # Update poll options with vote counts
    poll = await db.polls.find_one({"id": poll_id})
    if poll:
        for option in poll["options"]:
            option["votes"] = vote_counts.get(option["id"], 0)
        
        await db.polls.update_one(
            {"id": poll_id},
            {"$set": {"options": poll["options"]}}
        )

@api_router.get("/polls/{poll_id}/results")
async def get_poll_results(poll_id: str):
    poll = await db.polls.find_one({"id": poll_id})
    if not poll:
        raise HTTPException(status_code=404, detail="Poll not found")
    
    await update_poll_results(poll_id)
    updated_poll = await db.polls.find_one({"id": poll_id})
    
    total_votes = sum(opt["votes"] for opt in updated_poll["options"])
    
    results = []
    for option in updated_poll["options"]:
        percentage = (option["votes"] / total_votes * 100) if total_votes > 0 else 0
        results.append({
            "option": option["text"],
            "votes": option["votes"],
            "percentage": round(percentage, 1)
        })
    
    return {
        "question": updated_poll["question"],
        "results": results,
        "total_votes": total_votes
    }

# WebSocket endpoint
@app.websocket("/ws/meetings/{meeting_id}")
async def websocket_endpoint(websocket: WebSocket, meeting_id: str):
    await manager.connect(websocket, meeting_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket, meeting_id)

# Include the router in the main app
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()