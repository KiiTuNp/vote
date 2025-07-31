import React, { useState, useEffect } from "react";
import "./App.css";
import axios from "axios";
import { Button } from "./components/ui/button";
import { Input } from "./components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "./components/ui/card";
import { Badge } from "./components/ui/badge";
import { Progress } from "./components/ui/progress";
import { Separator } from "./components/ui/separator";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "./components/ui/tabs";
import { CheckCircle, Clock, Users, Vote, AlertCircle, Play, Square, Download, FileText } from "lucide-react";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || import.meta.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

console.log("🔍 Environment loaded:", { BACKEND_URL, API });

function App() {
  const [currentView, setCurrentView] = useState("home"); // home, create, join, organizer, participant
  const [meeting, setMeeting] = useState(null);
  const [participant, setParticipant] = useState(null);
  const [ws, setWs] = useState(null);

  // Home Component
  const Home = () => {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 flex items-center justify-center p-4">
        <Card className="w-full max-w-md">
          <CardHeader className="text-center">
            <div className="mx-auto mb-4 w-16 h-16 bg-blue-600 rounded-full flex items-center justify-center">
              <Vote className="w-8 h-8 text-white" />
            </div>
            <CardTitle className="text-2xl font-bold text-slate-800">Vote Secret</CardTitle>
            <CardDescription>
              Système de vote anonyme pour assemblées
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Button 
              onClick={() => setCurrentView("create")} 
              className="w-full bg-blue-600 hover:bg-blue-700"
            >
              Créer une réunion
            </Button>
            <Button 
              onClick={() => setCurrentView("join")} 
              variant="outline" 
              className="w-full"
            >
              Rejoindre une réunion
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  };

  // Create Meeting Component
  const CreateMeeting = () => {
    const [title, setTitle] = useState("");
    const [organizerName, setOrganizerName] = useState("");
    const [loading, setLoading] = useState(false);

    const handleCreate = async (e) => {
      e.preventDefault();
      console.log("🔍 handleCreate called with:", { title, organizerName });
      console.log("🔍 Backend URL:", BACKEND_URL, "API:", API);
      
      if (!title || !organizerName) {
        console.log("❌ Missing title or organizer name");
        alert("Veuillez remplir tous les champs");
        return;
      }
      
      setLoading(true);
      try {
        console.log("🚀 Making API call to create meeting...");
        const response = await axios.post(`${API}/meetings`, {
          title,
          organizer_name: organizerName
        });
        console.log("✅ Meeting created successfully:", response.data);
        setMeeting(response.data);
        setCurrentView("organizer");
        connectWebSocket(response.data.id);
      } catch (error) {
        console.error("❌ Error creating meeting:", error);
        alert("Erreur lors de la création de la réunion: " + (error.response?.data?.detail || error.message));
      } finally {
        setLoading(false);
      }
    };

    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 flex items-center justify-center p-4">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle>Créer une réunion</CardTitle>
            <CardDescription>
              Configurez votre session de vote
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleCreate} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">Titre de la réunion</label>
                <Input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="ex: Assemblée générale 2025"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-2">Votre nom</label>
                <Input
                  type="text"
                  value={organizerName}
                  onChange={(e) => setOrganizerName(e.target.value)}
                  placeholder="ex: Jean Dupont"
                  required
                />
              </div>
              <div className="flex space-x-2">
                <Button 
                  type="button"
                  onClick={() => setCurrentView("home")} 
                  variant="outline" 
                  className="flex-1"
                >
                  Retour
                </Button>
                <Button 
                  type="submit"
                  disabled={!title || !organizerName || loading}
                  className="flex-1 bg-blue-600 hover:bg-blue-700"
                >
                  {loading ? "Création..." : "Créer"}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    );
  };

  // Join Meeting Component
  const JoinMeeting = () => {
    const [name, setName] = useState("");
    const [meetingCode, setMeetingCode] = useState("");
    const [loading, setLoading] = useState(false);

    const handleJoin = async (e) => {
      e.preventDefault();
      console.log("🔍 handleJoin called with:", { name, meetingCode });
      
      if (!name || !meetingCode) {
        alert("Veuillez remplir tous les champs");
        return;
      }
      
      setLoading(true);
      try {
        console.log("🚀 Making API call to join meeting...");
        const response = await axios.post(`${API}/participants/join`, {
          name,
          meeting_code: meetingCode.toUpperCase()
        });
        console.log("✅ Successfully joined meeting:", response.data);
        setParticipant(response.data);
        
        // Get meeting details
        const meetingResponse = await axios.get(`${API}/meetings/${meetingCode.toUpperCase()}`);
        setMeeting(meetingResponse.data);
        
        setCurrentView("participant");
        connectWebSocket(meetingResponse.data.id);
      } catch (error) {
        console.error("❌ Error joining meeting:", error);
        alert("Erreur: " + (error.response?.data?.detail || "Impossible de rejoindre la réunion"));
      } finally {
        setLoading(false);
      }
    };

    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 flex items-center justify-center p-4">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle>Rejoindre une réunion</CardTitle>
            <CardDescription>
              Entrez vos informations pour participer
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleJoin} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">Votre nom</label>
                <Input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="ex: Marie Martin"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-2">Code de réunion</label>
                <Input
                  type="text"
                  value={meetingCode}
                  onChange={(e) => setMeetingCode(e.target.value.toUpperCase())}
                  placeholder="ex: ABC12345"
                  className="font-mono"
                  required
                />
              </div>
              <div className="flex space-x-2">
                <Button 
                  type="button"
                  onClick={() => setCurrentView("home")} 
                  variant="outline" 
                  className="flex-1"
                >
                  Retour
                </Button>
                <Button 
                  type="submit"
                  disabled={!name || !meetingCode || loading}
                  className="flex-1 bg-blue-600 hover:bg-blue-700"
                >
                  {loading ? "Connexion..." : "Rejoindre"}  
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    );
  };

  // Organizer Dashboard Component
  const OrganizerDashboard = () => {
    const [participants, setParticipants] = useState([]);
    const [polls, setPolls] = useState([]);
    const [newPollQuestion, setNewPollQuestion] = useState("");
    const [newPollOptions, setNewPollOptions] = useState(["", ""]);
    const [timerDuration, setTimerDuration] = useState("");

    useEffect(() => {
      if (meeting) {
        loadOrganizerData();
        // Set up polling for real-time updates every 3 seconds
        const interval = setInterval(() => {
          loadOrganizerData();
        }, 3000);
        
        return () => clearInterval(interval);
      }
    }, [meeting]);

    const loadOrganizerData = async () => {
      try {
        const response = await axios.get(`${API}/meetings/${meeting.id}/organizer`);
        setParticipants(response.data.participants);
        setPolls(response.data.polls);
      } catch (error) {
        console.error("Error loading organizer data:", error);
      }
    };

    const approveParticipant = async (participantId, approved) => {
      try {
        await axios.post(`${API}/participants/${participantId}/approve`, {
          participant_id: participantId,
          approved
        });
        loadOrganizerData();
      } catch (error) {
        console.error("Error approving participant:", error);
      }
    };

    const createPoll = async () => {
      if (!newPollQuestion || newPollOptions.some(opt => !opt.trim())) return;
      
      try {
        await axios.post(`${API}/meetings/${meeting.id}/polls`, {
          question: newPollQuestion,
          options: newPollOptions.filter(opt => opt.trim()),
          timer_duration: timerDuration ? parseInt(timerDuration) : null
        });
        
        setNewPollQuestion("");
        setNewPollOptions(["", ""]);
        setTimerDuration("");
        loadOrganizerData();
      } catch (error) {
        console.error("Error creating poll:", error);
      }
    };

    const startPoll = async (pollId) => {
      try {
        await axios.post(`${API}/polls/${pollId}/start`);
        loadOrganizerData();
      } catch (error) {
        console.error("Error starting poll:", error);
      }
    };

    const closePoll = async (pollId) => {
      try {
        await axios.post(`${API}/polls/${pollId}/close`);
        loadOrganizerData();
      } catch (error) {
        console.error("Error closing poll:", error);
      }
    };

    const addPollOption = () => {
      setNewPollOptions([...newPollOptions, ""]);
    };

    const updatePollOption = (index, value) => {
      const updated = [...newPollOptions];
      updated[index] = value;
      setNewPollOptions(updated);
    };

    const removePollOption = (index) => {
      if (newPollOptions.length > 2) {
        setNewPollOptions(newPollOptions.filter((_, i) => i !== index));
      }
    };

    const downloadReport = async () => {
      if (!meeting?.id) return;
      
      try {
        const confirmed = window.confirm(
          "⚠️ ATTENTION: Cette action va télécharger le rapport PDF et supprimer définitivement toutes les données de la réunion.\n\nCette action est IRRÉVERSIBLE.\n\nÊtes-vous sûr de vouloir continuer ?"
        );
        
        if (!confirmed) return;
        
        // Create download link
        const downloadUrl = `${API}/meetings/${meeting.id}/report`;
        
        // Create temporary link to trigger download
        const link = document.createElement('a');
        link.href = downloadUrl;
        link.download = `Rapport_${meeting.title}_${meeting.meeting_code}.pdf`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        
        // Show success message and redirect
        setTimeout(() => {
          alert("✅ Rapport téléchargé avec succès!\n\n📝 Toutes les données de la réunion ont été supprimées.\n\n🏠 Retour à l'accueil...");
          setCurrentView("home");
          setMeeting(null);
        }, 2000);
        
      } catch (error) {
        console.error("Error downloading report:", error);
        alert("❌ Erreur lors du téléchargement du rapport: " + (error.response?.data?.detail || "Erreur inconnue"));
      }
    };

    return (
      <div className="min-h-screen bg-slate-50 p-4">
        <div className="max-w-6xl mx-auto">
          <Card className="mb-6">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Vote className="w-5 h-5" />
                {meeting?.title}
              </CardTitle>
              <CardDescription>
                Code de réunion: <span className="font-mono font-bold text-lg">{meeting?.meeting_code}</span>
              </CardDescription>
            </CardHeader>
          </Card>

          <Tabs defaultValue="participants" className="space-y-6">
            <TabsList className="grid w-full grid-cols-4">
              <TabsTrigger value="participants">
                <Users className="w-4 h-4 mr-2" />
                Participants ({participants.length})
              </TabsTrigger>
              <TabsTrigger value="polls">
                <Vote className="w-4 h-4 mr-2" />
                Sondages ({polls.length})
              </TabsTrigger>
              <TabsTrigger value="create-poll">
                Créer un sondage
              </TabsTrigger>
              <TabsTrigger value="report">
                Rapport Final
              </TabsTrigger>
            </TabsList>

            <TabsContent value="participants">
              <Card>
                <CardHeader>
                  <CardTitle>Gestion des participants</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3">
                    {participants.map((participant) => (
                      <div key={participant.id} className="flex items-center justify-between p-3 border rounded-lg">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 bg-slate-200 rounded-full flex items-center justify-center">
                            {participant.name.charAt(0).toUpperCase()}
                          </div>
                          <div>
                            <p className="font-medium">{participant.name}</p>
                            <p className="text-sm text-slate-500">
                              Rejoint le {new Date(participant.joined_at).toLocaleTimeString()}
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center gap-2">
                          {participant.approval_status === "pending" && (
                            <>
                              <Button size="sm" onClick={() => approveParticipant(participant.id, true)}>
                                Approuver
                              </Button>
                              <Button size="sm" variant="outline" onClick={() => approveParticipant(participant.id, false)}>
                                Rejeter
                              </Button>
                            </>
                          )}
                          {participant.approval_status === "approved" && (
                            <Badge variant="default">
                              <CheckCircle className="w-3 h-3 mr-1" />
                              Approuvé
                            </Badge>
                          )}
                          {participant.approval_status === "rejected" && (
                            <Badge variant="destructive">Rejeté</Badge>
                          )}
                        </div>
                      </div>
                    ))}
                    {participants.length === 0 && (
                      <p className="text-center text-slate-500 py-8">
                        Aucun participant n'a encore rejoint la réunion
                      </p>
                    )}
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="polls">
              <div className="space-y-4">
                {polls.map((poll) => (
                  <Card key={poll.id}>
                    <CardHeader>
                      <div className="flex items-center justify-between">
                        <CardTitle className="text-lg">{poll.question}</CardTitle>
                        <div className="flex items-center gap-2">
                          {poll.status === "draft" && (
                            <Button size="sm" onClick={() => startPoll(poll.id)}>
                              <Play className="w-4 h-4 mr-1" />
                              Lancer
                            </Button>
                          )}
                          {poll.status === "active" && (
                            <>
                              <Badge variant="default">
                                <Clock className="w-3 h-3 mr-1" />
                                En cours
                              </Badge>
                              <Button size="sm" variant="outline" onClick={() => closePoll(poll.id)}>
                                <Square className="w-4 h-4 mr-1" />
                                Fermer
                              </Button>
                            </>
                          )}
                          {poll.status === "closed" && (
                            <Badge variant="secondary">Fermé</Badge>
                          )}
                        </div>
                      </div>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        {poll.options.map((option) => {
                          const totalVotes = poll.options.reduce((sum, opt) => sum + opt.votes, 0);
                          const percentage = totalVotes > 0 ? (option.votes / totalVotes) * 100 : 0;
                          
                          return (
                            <div key={option.id} className="space-y-2">
                              <div className="flex justify-between text-sm">
                                <span>{option.text}</span>
                                <span className="font-medium">
                                  {option.votes} votes ({percentage.toFixed(1)}%)
                                </span>
                              </div>
                              <Progress value={percentage} className="h-2" />
                            </div>
                          );
                        })}
                      </div>
                      {poll.timer_duration && (
                        <div className="mt-4 p-3 bg-blue-50 rounded-lg">
                          <p className="text-sm text-blue-700">
                            <Clock className="w-4 h-4 inline mr-1" />
                            Durée du minuteur: {poll.timer_duration} secondes
                          </p>
                        </div>
                      )}
                    </CardContent>
                  </Card>
                ))}
                {polls.length === 0 && (
                  <Card>
                    <CardContent className="text-center py-8">
                      <p className="text-slate-500">Aucun sondage créé pour le moment</p>
                    </CardContent>
                  </Card>
                )}
              </div>
            </TabsContent>

            <TabsContent value="create-poll">
              <Card>
                <CardHeader>
                  <CardTitle>Créer un nouveau sondage</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium mb-2">Question</label>
                    <Input
                      value={newPollQuestion}
                      onChange={(e) => setNewPollQuestion(e.target.value)}
                      placeholder="ex: Approuvez-vous cette proposition ?"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium mb-2">Options de réponse</label>
                    <div className="space-y-2">
                      {newPollOptions.map((option, index) => (
                        <div key={index} className="flex gap-2">
                          <Input
                            value={option}
                            onChange={(e) => updatePollOption(index, e.target.value)}
                            placeholder={`Option ${index + 1}`}
                          />
                          {newPollOptions.length > 2 && (
                            <Button
                              type="button"
                              variant="outline"
                              size="sm"
                              onClick={() => removePollOption(index)}
                            >
                              ×
                            </Button>
                          )}
                        </div>
                      ))}
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onClick={addPollOption}
                      >
                        + Ajouter une option
                      </Button>
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-2">
                      Minuteur (optionnel, en secondes)
                    </label>
                    <Input
                      type="number"
                      value={timerDuration}
                      onChange={(e) => setTimerDuration(e.target.value)}
                      placeholder="ex: 60"
                    />
                  </div>

                  <Button 
                    onClick={createPoll}
                    disabled={!newPollQuestion || newPollOptions.some(opt => !opt.trim())}
                    className="w-full"
                  >
                    Créer le sondage
                  </Button>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="report">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <FileText className="w-5 h-5" />
                    Rapport Final de la Réunion
                  </CardTitle>
                  <CardDescription>
                    Téléchargez le rapport PDF contenant tous les résultats. 
                    <strong className="text-red-600"> Attention: Cette action supprimera définitivement toutes les données de la réunion.</strong>
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-6">
                  <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                    <h3 className="font-semibold text-yellow-800 mb-2">⚠️ Important</h3>
                    <ul className="text-sm text-yellow-700 space-y-1">
                      <li>• Le rapport PDF contiendra la liste des participants approuvés</li>
                      <li>• Tous les résultats de sondages avec votes et pourcentages</li>
                      <li>• Une fois téléchargé, toutes les données seront supprimées</li>
                      <li>• Cette action est irréversible</li>
                    </ul>
                  </div>

                  <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <h3 className="font-semibold text-blue-800 mb-2">📊 Résumé de la réunion</h3>
                    <div className="text-sm text-blue-700 space-y-1">
                      <p><strong>Participants approuvés:</strong> {participants.filter(p => p.approval_status === 'approved').length}</p>
                      <p><strong>Sondages créés:</strong> {polls.length}</p>
                      <p><strong>Sondages fermés:</strong> {polls.filter(p => p.status === 'closed').length}</p>
                    </div>
                  </div>

                  <Button 
                    onClick={downloadReport}
                    className="w-full bg-red-600 hover:bg-red-700 text-white"
                    size="lg"
                  >
                    <Download className="w-5 h-5 mr-2" />
                    Télécharger le Rapport Final et Terminer la Réunion
                  </Button>

                  <p className="text-xs text-slate-500 text-center">
                    En cliquant sur ce bouton, vous acceptez la suppression définitive de toutes les données de cette réunion
                  </p>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        </div>
      </div>
    );
  };

  // Participant Dashboard Component
  const ParticipantDashboard = () => {
    const [status, setStatus] = useState("pending");
    const [polls, setPolls] = useState([]);
    const [votedPolls, setVotedPolls] = useState(new Set());

    useEffect(() => {
      if (participant) {
        checkParticipantStatus();
        loadPolls();
        
        // Set up polling for participant status and new polls (but NOT results)
        const interval = setInterval(() => {
          checkParticipantStatus();
          loadPolls();
        }, 3000);
        
        return () => clearInterval(interval);
      }
    }, [participant]);

    const checkParticipantStatus = async () => {
      try {
        const response = await axios.get(`${API}/participants/${participant.id}/status`);
        setStatus(response.data.status);
      } catch (error) {
        console.error("Error checking status:", error);
      }
    };

    const loadPolls = async () => {
      if (!meeting) return;
      try {
        const response = await axios.get(`${API}/meetings/${meeting.id}/polls`);
        // Pour les participants, on ne met à jour les résultats QUE pour les sondages où ils ont déjà voté
        const pollsData = response.data.map(poll => {
          if (!votedPolls.has(poll.id)) {
            // Si le participant n'a pas encore voté, on efface les compteurs de votes
            return {
              ...poll,
              options: poll.options.map(option => ({
                ...option,
                votes: 0  // Masquer les vrais résultats
              }))
            };
          }
          return poll; // Si déjà voté, garder les vrais résultats
        });
        setPolls(pollsData);
      } catch (error) {
        console.error("Error loading polls:", error);
      }
    };

    const submitVote = async (pollId, optionId) => {
      try {
        await axios.post(`${API}/votes`, {
          poll_id: pollId,
          option_id: optionId
        });
        
        // Marquer ce sondage comme voté
        setVotedPolls(prev => new Set([...prev, pollId]));
        
        // MAINTENANT charger les vrais résultats pour ce sondage
        loadPollResults(pollId);
      } catch (error) {
        console.error("Error submitting vote:", error);
        alert("Erreur lors du vote: " + (error.response?.data?.detail || "Erreur inconnue"));
      }
    };

    const loadPollResults = async (pollId) => {
      try {
        const response = await axios.get(`${API}/meetings/${meeting.id}/polls`);
        const updatedPolls = response.data;
        setPolls(updatedPolls);
      } catch (error) {
        console.error("Error loading poll results:", error);
      }
    };

    if (status === "pending") {
      return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
          <Card className="w-full max-w-md">
            <CardContent className="text-center py-8">
              <AlertCircle className="w-16 h-16 text-yellow-500 mx-auto mb-4" />
              <h2 className="text-xl font-bold mb-2">En attente d'approbation</h2>
              <p className="text-slate-600 mb-4">
                Votre demande de participation est en cours d'examen par l'organisateur.
              </p>
              <p className="text-sm text-slate-500">
                Réunion: {meeting?.title}<br />
                Participant: {participant?.name}
              </p>
            </CardContent>
          </Card>
        </div>
      );
    }

    if (status === "rejected") {
      return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
          <Card className="w-full max-w-md">
            <CardContent className="text-center py-8">
              <AlertCircle className="w-16 h-16 text-red-500 mx-auto mb-4" />
              <h2 className="text-xl font-bold mb-2">Accès refusé</h2>
              <p className="text-slate-600 mb-4">
                Votre demande de participation a été refusée par l'organisateur.
              </p>
              <Button onClick={() => setCurrentView("home")}>
                Retour à l'accueil
              </Button>
            </CardContent>
          </Card>
        </div>
      );
    }

    return (
      <div className="min-h-screen bg-slate-50 p-4">
        <div className="max-w-2xl mx-auto">
          <Card className="mb-6">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <CheckCircle className="w-5 h-5 text-green-600" />
                {meeting?.title}
              </CardTitle>
              <CardDescription>
                Participant: {participant?.name} - Statut: Approuvé
              </CardDescription>
            </CardHeader>
          </Card>

          <div className="space-y-4">
            {polls
              .filter(poll => poll.status === "active")
              .map((poll) => (
                <Card key={poll.id}>
                  <CardHeader>
                    <CardTitle className="text-lg">{poll.question}</CardTitle>
                    {!votedPolls.has(poll.id) && (
                      <CardDescription>
                        <span className="text-blue-600 font-medium">
                          🔒 Votez pour voir les résultats
                        </span>
                      </CardDescription>
                    )}
                    {votedPolls.has(poll.id) && (
                      <CardDescription>
                        <span className="text-green-600 font-medium">
                          ✅ Vous avez voté - Résultats en temps réel
                        </span>
                      </CardDescription>
                    )}
                  </CardHeader>
                  <CardContent>
                    {!votedPolls.has(poll.id) ? (
                      <div className="space-y-2">
                        {poll.options.map((option) => (
                          <Button
                            key={option.id}
                            variant="outline"
                            className="w-full justify-start"
                            onClick={() => submitVote(poll.id, option.id)}
                          >
                            {option.text}
                          </Button>
                        ))}
                        <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
                          <p className="text-sm text-blue-700">
                            <span className="font-semibold">🔒 Vote secret:</span> Les résultats ne s'affichent qu'après avoir voté
                          </p>
                        </div>
                      </div>
                    ) : (
                      <div className="space-y-3">
                        {poll.options.map((option) => {
                          const totalVotes = poll.options.reduce((sum, opt) => sum + opt.votes, 0);
                          const percentage = totalVotes > 0 ? (option.votes / totalVotes) * 100 : 0;
                          
                          return (
                            <div key={option.id} className="space-y-2">
                              <div className="flex justify-between text-sm">
                                <span>{option.text}</span>
                                <span className="font-medium">
                                  {option.votes} votes ({percentage.toFixed(1)}%)
                                </span>
                              </div>
                              <Progress value={percentage} className="h-2" />
                            </div>
                          );
                        })}
                        <div className="mt-4 p-3 bg-green-50 border border-green-200 rounded-lg">
                          <p className="text-sm text-green-700">
                            <span className="font-semibold">✅ Vote enregistré!</span> Les résultats se mettent à jour automatiquement
                          </p>
                        </div>
                      </div>
                    )}
                  </CardContent>
                </Card>
              ))}

            {polls.filter(poll => poll.status === "active").length === 0 && (
              <Card>
                <CardContent className="text-center py-8">
                  <p className="text-slate-500">Aucun sondage actif pour le moment</p>
                  <p className="text-sm text-slate-400 mt-2">
                    Les nouveaux sondages apparaîtront ici automatiquement
                  </p>
                </CardContent>
              </Card>
            )}
          </div>
        </div>
      </div>
    );
  };

  // WebSocket connection
  const connectWebSocket = (meetingId) => {
    const wsUrl = `${BACKEND_URL.replace('https://', 'wss://').replace('http://', 'ws://')}/ws/meetings/${meetingId}`;
    const websocket = new WebSocket(wsUrl);
    
    websocket.onopen = () => {
      console.log("WebSocket connected to:", wsUrl);
      setWs(websocket);
    };
    
    websocket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      console.log("WebSocket message received:", data);
      
      // Handle real-time updates based on message type
      if (data.type === "participant_joined" || data.type === "participant_approved") {
        console.log("Participant update received, refreshing organizer view");
        // Force refresh for organizer view
        setTimeout(() => {
          window.location.reload();
        }, 500);
      }
      
      if (data.type === "poll_started" || data.type === "poll_closed" || data.type === "vote_submitted") {
        console.log("Poll update received, refreshing view");
        // Force refresh for poll updates
        setTimeout(() => {
          window.location.reload();
        }, 500);
      }
    };
    
    websocket.onerror = (error) => {
      console.error("WebSocket error:", error);
    };
    
    websocket.onclose = () => {
      console.log("WebSocket disconnected");
      setWs(null);
    };
  };

  // Render current view
  const renderCurrentView = () => {
    switch (currentView) {
      case "home":
        return <Home />;
      case "create":
        return <CreateMeeting />;
      case "join":
        return <JoinMeeting />;
      case "organizer":
        return <OrganizerDashboard />;
      case "participant":
        return <ParticipantDashboard />;
      default:
        return <Home />;
    }
  };

  return (
    <div className="App">
      {renderCurrentView()}
    </div>
  );
}

export default App;