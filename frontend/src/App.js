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
import { Switch } from "./components/ui/switch";
import { CheckCircle, Clock, Users, Vote, AlertCircle, Play, Square, Download, FileText, Settings, UserPlus, Sparkles, Shield, BarChart3, Timer } from "lucide-react";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || import.meta.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

console.log("🔍 Environment loaded:", { BACKEND_URL, API });

function App() {
  const [currentView, setCurrentView] = useState("home");
  const [meeting, setMeeting] = useState(null);
  const [participant, setParticipant] = useState(null);
  const [ws, setWs] = useState(null);

  // Particle background effect
  useEffect(() => {
    const createParticle = () => {
      const particle = document.createElement('div');
      particle.className = 'particle';
      particle.style.left = Math.random() * 100 + 'vw';
      particle.style.width = Math.random() * 4 + 2 + 'px';
      particle.style.height = particle.style.width;
      particle.style.animationDuration = Math.random() * 3 + 3 + 's';
      particle.style.animationDelay = Math.random() * 2 + 's';
      
      document.body.appendChild(particle);
      
      setTimeout(() => {
        if (particle.parentNode) {
          particle.parentNode.removeChild(particle);
        }
      }, 6000);
    };

    const particleInterval = setInterval(createParticle, 300);
    return () => clearInterval(particleInterval);
  }, []);

  // Home Component - Modern Design
  const Home = () => {
    return (
      <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-cyan-50 bg-pattern-dots flex items-center justify-center p-4">
        <div className="w-full max-w-6xl mx-auto">
          {/* Hero Section */}
          <div className="text-center mb-12">
            <div className="hero-animate inline-block mb-6">
              <div className="w-24 h-24 mx-auto bg-gradient-to-br from-indigo-500 to-purple-600 rounded-3xl flex items-center justify-center shadow-2xl">
                <Vote className="w-12 h-12 text-white" />
              </div>
            </div>
            <h1 className="text-5xl md:text-7xl font-black text-modern-heading gradient-text mb-4">
              Vote Secret
            </h1>
            <p className="text-xl md:text-2xl text-modern-body max-w-3xl mx-auto mb-8">
              Système de vote anonyme moderne pour assemblées avec suppression automatique des données
            </p>
            
            {/* Features Grid */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12 max-w-4xl mx-auto">
              <div className="glass-card p-6">
                <Shield className="w-8 h-8 text-indigo-600 mx-auto mb-3" />
                <h3 className="font-bold text-slate-800 mb-2">100% Anonyme</h3>
                <p className="text-sm text-slate-600">Aucune traçabilité des votes</p>
              </div>
              <div className="glass-card p-6">
                <BarChart3 className="w-8 h-8 text-purple-600 mx-auto mb-3" />
                <h3 className="font-bold text-slate-800 mb-2">Temps Réel</h3>
                <p className="text-sm text-slate-600">Résultats instantanés</p>
              </div>
              <div className="glass-card p-6">
                <FileText className="w-8 h-8 text-cyan-600 mx-auto mb-3" />
                <h3 className="font-bold text-slate-800 mb-2">Rapport PDF</h3>
                <p className="text-sm text-slate-600">Auto-destruction des données</p>
              </div>
            </div>
          </div>

          {/* Main Actions */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 max-w-4xl mx-auto">
            {/* Participant Action - Prominent */}
            <div className="order-1 lg:order-1">
              <Card className="glass-card-strong border-0 shadow-2xl overflow-hidden">
                <CardHeader className="bg-gradient-to-r from-indigo-500 to-purple-600 text-white pb-8">
                  <div className="flex items-center justify-center mb-4">
                    <UserPlus className="w-12 h-12" />
                  </div>
                  <CardTitle className="text-2xl md:text-3xl font-bold text-center">
                    Rejoindre une Réunion
                  </CardTitle>
                  <CardDescription className="text-indigo-100 text-center text-lg">
                    Participez à un vote avec votre code de réunion
                  </CardDescription>
                </CardHeader>
                <CardContent className="p-8">
                  <div className="space-y-4 mb-6">
                    <div className="flex items-center gap-3 text-slate-600">
                      <div className="w-8 h-8 bg-indigo-100 rounded-full flex items-center justify-center">
                        <span className="text-indigo-600 font-bold text-sm">1</span>
                      </div>
                      <span>Entrez votre nom et le code de réunion</span>
                    </div>
                    <div className="flex items-center gap-3 text-slate-600">
                      <div className="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center">
                        <span className="text-purple-600 font-bold text-sm">2</span>
                      </div>
                      <span>Attendez l'approbation de l'organisateur</span>
                    </div>
                    <div className="flex items-center gap-3 text-slate-600">
                      <div className="w-8 h-8 bg-cyan-100 rounded-full flex items-center justify-center">
                        <span className="text-cyan-600 font-bold text-sm">3</span>
                      </div>
                      <span>Votez en toute confidentialité</span>
                    </div>
                  </div>
                  <Button 
                    onClick={() => setCurrentView("join")} 
                    className="w-full h-14 text-lg font-bold btn-gradient-primary"
                  >
                    <UserPlus className="w-6 h-6 mr-2" />
                    Rejoindre Maintenant
                  </Button>
                </CardContent>
              </Card>
            </div>

            {/* Organizer Action - Elegant and Discrete */}
            <div className="order-2 lg:order-2">
              <Card className="glass-card border-0 shadow-xl hover:shadow-2xl transition-all duration-300 overflow-hidden">
                <CardHeader className="bg-gradient-to-r from-emerald-400 via-teal-500 to-cyan-600 text-white relative">
                  <div className="absolute inset-0 bg-white bg-opacity-10"></div>
                  <div className="relative z-10">
                    <div className="flex items-center justify-center mb-3">
                      <div className="w-10 h-10 bg-white bg-opacity-20 rounded-xl flex items-center justify-center">
                        <Settings className="w-6 h-6" />
                      </div>
                    </div>
                    <CardTitle className="text-xl font-bold text-center">
                      Interface Organisateur
                    </CardTitle>
                    <CardDescription className="text-emerald-100 text-center">
                      Créez et gérez votre réunion de vote
                    </CardDescription>
                  </div>
                </CardHeader>
                <CardContent className="p-6 bg-gradient-to-br from-white to-slate-50">
                  <div className="space-y-3 mb-6 text-sm">
                    <div className="flex items-center gap-3 text-slate-700 p-2 rounded-lg bg-gradient-to-r from-emerald-50 to-teal-50">
                      <div className="w-6 h-6 bg-gradient-to-br from-emerald-400 to-teal-500 rounded-full flex items-center justify-center">
                        <Vote className="w-3 h-3 text-white" />
                      </div>
                      <span className="font-medium">Créer des sondages</span>
                    </div>
                    <div className="flex items-center gap-3 text-slate-700 p-2 rounded-lg bg-gradient-to-r from-teal-50 to-cyan-50">
                      <div className="w-6 h-6 bg-gradient-to-br from-teal-400 to-cyan-500 rounded-full flex items-center justify-center">
                        <Users className="w-3 h-3 text-white" />
                      </div>
                      <span className="font-medium">Gérer les participants</span>
                    </div>
                    <div className="flex items-center gap-3 text-slate-700 p-2 rounded-lg bg-gradient-to-r from-cyan-50 to-blue-50">
                      <div className="w-6 h-6 bg-gradient-to-br from-cyan-400 to-blue-500 rounded-full flex items-center justify-center">
                        <FileText className="w-3 h-3 text-white" />
                      </div>
                      <span className="font-medium">Générer le rapport</span>
                    </div>
                  </div>
                  <Button 
                    onClick={() => setCurrentView("create")} 
                    variant="outline" 
                    className="w-full h-12 border-2 border-emerald-200 hover:bg-gradient-to-r hover:from-emerald-500 hover:to-teal-600 hover:text-white hover:border-transparent transition-all duration-300"
                  >
                    <Settings className="w-5 h-5 mr-2" />
                    Accès Organisateur
                  </Button>
                </CardContent>
              </Card>
            </div>
          </div>

          {/* Footer */}
          <div className="text-center mt-12 text-slate-500">
            <p className="flex items-center justify-center gap-2">
              <Sparkles className="w-4 h-4" />
              Vote Secret v2.0 - Technologie 2025
              <Sparkles className="w-4 h-4" />
            </p>
          </div>
        </div>
      </div>
    );
  };

  // Create Meeting Component - Enhanced
  const CreateMeeting = () => {
    const [title, setTitle] = useState("");
    const [organizerName, setOrganizerName] = useState("");
    const [loading, setLoading] = useState(false);

    const handleCreate = async (e) => {
      e.preventDefault();
      console.log("🔍 handleCreate called with:", { title, organizerName });
      
      if (!title || !organizerName) {
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
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 bg-pattern-grid flex items-center justify-center p-4">
        <Card className="glass-card-strong w-full max-w-md border-0 shadow-2xl">
          <CardHeader className="bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-t-2xl">
            <div className="w-16 h-16 bg-white bg-opacity-20 rounded-full flex items-center justify-center mx-auto mb-4">
              <Settings className="w-8 h-8" />
            </div>
            <CardTitle className="text-2xl font-bold text-center">Créer une Réunion</CardTitle>
            <CardDescription className="text-purple-100 text-center">
              Configurez votre session de vote anonyme
            </CardDescription>
          </CardHeader>
          <CardContent className="p-8">
            <form onSubmit={handleCreate} className="space-y-6">
              <div>
                <label className="block text-sm font-semibold mb-3 text-slate-700">
                  Titre de la réunion
                </label>
                <Input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="ex: Assemblée générale 2025"
                  required
                  className="h-12 input-modern border-slate-300 focus:border-indigo-500"
                />
              </div>
              <div>
                <label className="block text-sm font-semibold mb-3 text-slate-700">
                  Votre nom (organisateur)
                </label>
                <Input
                  type="text"
                  value={organizerName}
                  onChange={(e) => setOrganizerName(e.target.value)}
                  placeholder="ex: Jean Dupont"
                  required
                  className="h-12 input-modern border-slate-300 focus:border-indigo-500"
                />
              </div>
              <div className="flex space-x-3 pt-4">
                <Button 
                  type="button"
                  onClick={() => setCurrentView("home")} 
                  variant="outline" 
                  className="flex-1 h-12 border-slate-300"
                >
                  Retour
                </Button>
                <Button 
                  type="submit"
                  disabled={!title || !organizerName || loading}
                  className="flex-1 h-12 btn-gradient-primary"
                >
                  {loading ? (
                    <>
                      <div className="spinner-modern mr-2" />
                      Création...
                    </>
                  ) : (
                    <>
                      <Sparkles className="w-5 h-5 mr-2" />
                      Créer
                    </>
                  )}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    );
  };

  // Join Meeting Component - Enhanced
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
      <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-purple-50 to-cyan-50 bg-pattern-dots flex items-center justify-center p-4">
        <Card className="glass-card-strong w-full max-w-md border-0 shadow-2xl">
          <CardHeader className="bg-gradient-to-r from-indigo-500 to-purple-600 text-white rounded-t-2xl">
            <div className="w-16 h-16 bg-white bg-opacity-20 rounded-full flex items-center justify-center mx-auto mb-4">
              <UserPlus className="w-8 h-8" />
            </div>
            <CardTitle className="text-2xl font-bold text-center">Rejoindre une Réunion</CardTitle>
            <CardDescription className="text-indigo-100 text-center">
              Entrez vos informations pour participer au vote
            </CardDescription>
          </CardHeader>
          <CardContent className="p-8">
            <form onSubmit={handleJoin} className="space-y-6">
              <div>
                <label className="block text-sm font-semibold mb-3 text-slate-700">
                  Votre nom complet
                </label>
                <Input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="ex: Marie Martin"
                  required
                  className="h-12 input-modern border-slate-300 focus:border-indigo-500"
                />
              </div>
              <div>
                <label className="block text-sm font-semibold mb-3 text-slate-700">
                  Code de réunion
                </label>
                <Input
                  type="text"
                  value={meetingCode}
                  onChange={(e) => setMeetingCode(e.target.value.toUpperCase())}
                  placeholder="ex: ABC12345"
                  className="h-12 input-modern border-slate-300 focus:border-indigo-500 font-mono text-lg tracking-wider text-center"
                  required
                />
                <p className="text-xs text-slate-500 mt-2">
                  Demandez le code de réunion à l'organisateur
                </p>
              </div>
              <div className="flex space-x-3 pt-4">
                <Button 
                  type="button"
                  onClick={() => setCurrentView("home")} 
                  variant="outline" 
                  className="flex-1 h-12 border-slate-300"
                >
                  Retour
                </Button>
                <Button 
                  type="submit"
                  disabled={!name || !meetingCode || loading}
                  className="flex-1 h-12 btn-gradient-primary"
                >
                  {loading ? (
                    <>
                      <div className="spinner-modern mr-2" />
                      Connexion...
                    </>
                  ) : (
                    <>
                      <UserPlus className="w-5 h-5 mr-2" />
                      Rejoindre
                    </>
                  )}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    );
  };

  // Organizer Dashboard Component - Enhanced
  const OrganizerDashboard = () => {
    const [participants, setParticipants] = useState([]);
    const [polls, setPolls] = useState([]);
    const [newPollQuestion, setNewPollQuestion] = useState("");
    const [newPollOptions, setNewPollOptions] = useState(["", ""]);
    const [timerDuration, setTimerDuration] = useState("");
    const [showResultsRealTime, setShowResultsRealTime] = useState(true);

    useEffect(() => {
      if (meeting) {
        loadOrganizerData();
        const interval = setInterval(loadOrganizerData, 3000);
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
          timer_duration: timerDuration ? parseInt(timerDuration) : null,
          show_results_real_time: showResultsRealTime
        });
        
        setNewPollQuestion("");
        setNewPollOptions(["", ""]);
        setTimerDuration("");
        setShowResultsRealTime(true);
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
      <div className="min-h-screen bg-gradient-to-br from-slate-50 via-indigo-50 to-purple-50 bg-pattern-grid p-4">
        <div className="max-w-7xl mx-auto">
          {/* Header */}
          <Card className="glass-card-strong mb-8 border-0 shadow-xl">
            <CardHeader className="bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-t-2xl">
              <div className="flex flex-col md:flex-row items-center justify-between">
                <div className="flex items-center gap-4 mb-4 md:mb-0">
                  <div className="w-12 h-12 bg-white bg-opacity-20 rounded-xl flex items-center justify-center">
                    <Vote className="w-6 h-6" />
                  </div>
                  <div>
                    <CardTitle className="text-2xl font-bold">{meeting?.title}</CardTitle>
                    <CardDescription className="text-indigo-100">
                      Interface Organisateur
                    </CardDescription>
                  </div>
                </div>
                <div className="text-center">
                  <p className="text-indigo-100 text-sm mb-1">Code de réunion</p>
                  <div className="meeting-code bg-white bg-opacity-20 px-4 py-2 rounded-xl">
                    {meeting?.meeting_code}
                  </div>
                </div>
              </div>
            </CardHeader>
          </Card>

          <Tabs defaultValue="participants" className="space-y-6">
            <TabsList className="tabs-modern grid w-full grid-cols-2 md:grid-cols-4 h-14">
              <TabsTrigger value="participants" className="tab-modern h-10">
                <Users className="w-4 h-4 mr-2" />
                <span className="hidden sm:inline">Participants</span>
                <span className="sm:hidden">Part.</span>
                <Badge variant="secondary" className="ml-2 bg-white bg-opacity-80">
                  {participants.length}
                </Badge>
              </TabsTrigger>
              <TabsTrigger value="polls" className="tab-modern h-10">
                <Vote className="w-4 h-4 mr-2" />
                <span className="hidden sm:inline">Sondages</span>
                <span className="sm:hidden">Sond.</span>
                <Badge variant="secondary" className="ml-2 bg-white bg-opacity-80">
                  {polls.length}
                </Badge>
              </TabsTrigger>
              <TabsTrigger value="create-poll" className="tab-modern h-10">
                <Sparkles className="w-4 h-4 mr-2" />
                <span className="hidden sm:inline">Créer</span>
                <span className="sm:hidden">+</span>
              </TabsTrigger>
              <TabsTrigger value="report" className="tab-modern h-10">
                <FileText className="w-4 h-4 mr-2" />
                <span className="hidden sm:inline">Rapport</span>
                <span className="sm:hidden">PDF</span>
              </TabsTrigger>
            </TabsList>

            <TabsContent value="participants">
              <Card className="glass-card border-0 shadow-lg">
                <CardHeader className="bg-gradient-to-r from-cyan-500 to-blue-500 text-white rounded-t-xl">
                  <CardTitle className="flex items-center gap-2">
                    <Users className="w-5 h-5" />
                    Gestion des Participants
                  </CardTitle>
                </CardHeader>
                <CardContent className="p-6">
                  <div className="space-y-4">
                    {participants.map((participant) => (
                      <div key={participant.id} className="glass-card p-4 border border-slate-200">
                        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                          <div className="flex items-center gap-3">
                            <div className="w-12 h-12 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-full flex items-center justify-center text-white font-bold text-lg">
                              {participant.name.charAt(0).toUpperCase()}
                            </div>
                            <div>
                              <p className="font-semibold text-slate-800">{participant.name}</p>
                              <p className="text-sm text-slate-500">
                                Rejoint le {new Date(participant.joined_at).toLocaleTimeString()}
                              </p>
                            </div>
                          </div>
                          <div className="flex items-center gap-2">
                            {participant.approval_status === "pending" && (
                              <>
                                <Button 
                                  size="sm" 
                                  onClick={() => approveParticipant(participant.id, true)}
                                  className="btn-gradient-success"
                                >
                                  <CheckCircle className="w-4 h-4 mr-1" />
                                  Approuver
                                </Button>
                                <Button 
                                  size="sm" 
                                  variant="outline" 
                                  onClick={() => approveParticipant(participant.id, false)}
                                >
                                  Rejeter
                                </Button>
                              </>
                            )}
                            {participant.approval_status === "approved" && (
                              <Badge className="status-approved">
                                <CheckCircle className="w-3 h-3 mr-1" />
                                Approuvé
                              </Badge>
                            )}
                            {participant.approval_status === "rejected" && (
                              <Badge className="status-rejected">Rejeté</Badge>
                            )}
                          </div>
                        </div>
                      </div>
                    ))}
                    {participants.length === 0 && (
                      <div className="text-center py-12">
                        <UserPlus className="w-16 h-16 text-slate-300 mx-auto mb-4" />
                        <p className="text-slate-500 text-lg">Aucun participant n'a encore rejoint la réunion</p>
                        <p className="text-slate-400 text-sm mt-2">Partagez le code : <span className="font-mono font-bold">{meeting?.meeting_code}</span></p>
                      </div>
                    )}
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="polls">
              <div className="space-y-6">
                {polls.map((poll) => (
                  <Card key={poll.id} className="glass-card border-0 shadow-lg">
                    <CardHeader className="bg-gradient-to-r from-purple-500 to-pink-500 text-white rounded-t-xl">
                      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                        <CardTitle className="text-lg">{poll.question}</CardTitle>
                        <div className="flex items-center gap-2">
                          {poll.status === "draft" && (
                            <Button 
                              size="sm" 
                              onClick={() => startPoll(poll.id)}
                              className="btn-gradient-success"
                            >
                              <Play className="w-4 h-4 mr-1" />
                              Lancer
                            </Button>
                          )}
                          {poll.status === "active" && (
                            <>
                              <Badge className="status-approved">
                                <Clock className="w-3 h-3 mr-1" />
                                En cours
                              </Badge>
                              <Button 
                                size="sm" 
                                variant="outline"
                                onClick={() => closePoll(poll.id)}
                                className="border-white text-white hover:bg-white hover:text-purple-600"
                              >
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
                    <CardContent className="p-6">
                      <div className="space-y-4">
                        {poll.options.map((option) => {
                          const totalVotes = poll.options.reduce((sum, opt) => sum + opt.votes, 0);
                          const percentage = totalVotes > 0 ? (option.votes / totalVotes) * 100 : 0;
                          
                          return (
                            <div key={option.id} className="space-y-2">
                              <div className="flex justify-between text-sm">
                                <span className="font-medium">{option.text}</span>
                                <span className="font-bold text-slate-600">
                                  {option.votes} votes ({percentage.toFixed(1)}%)
                                </span>
                              </div>
                              <Progress value={percentage} className="h-3 progress-animated" />
                            </div>
                          );
                        })}
                      </div>
                      {poll.timer_duration && (
                        <div className="mt-4 p-4 bg-gradient-to-r from-blue-50 to-cyan-50 rounded-lg border border-blue-200">
                          <p className="text-sm text-blue-700 flex items-center gap-2">
                            <Timer className="w-4 h-4" />
                            Durée du minuteur: {poll.timer_duration} secondes
                          </p>
                        </div>
                      )}
                    </CardContent>
                  </Card>
                ))}
                {polls.length === 0 && (
                  <Card className="glass-card border-0 shadow-lg">
                    <CardContent className="text-center py-12">
                      <Vote className="w-16 h-16 text-slate-300 mx-auto mb-4" />
                      <p className="text-slate-500 text-lg">Aucun sondage créé pour le moment</p>
                      <p className="text-slate-400 text-sm mt-2">Créez votre premier sondage dans l'onglet "Créer"</p>
                    </CardContent>
                  </Card>
                )}
              </div>
            </TabsContent>

            <TabsContent value="create-poll">
              <Card className="glass-card border-0 shadow-lg">
                <CardHeader className="bg-gradient-to-r from-emerald-500 to-teal-500 text-white rounded-t-xl">
                  <CardTitle className="flex items-center gap-2">
                    <Sparkles className="w-5 h-5" />
                    Créer un Nouveau Sondage
                  </CardTitle>
                </CardHeader>
                <CardContent className="p-6 space-y-6">
                  <div>
                    <label className="block text-sm font-semibold mb-3 text-slate-700">Question du sondage</label>
                    <Input
                      value={newPollQuestion}
                      onChange={(e) => setNewPollQuestion(e.target.value)}
                      placeholder="ex: Approuvez-vous cette proposition ?"
                      className="h-12 input-modern"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-semibold mb-3 text-slate-700">Options de réponse</label>
                    <div className="space-y-3">
                      {newPollOptions.map((option, index) => (
                        <div key={index} className="flex gap-2">
                          <Input
                            value={option}
                            onChange={(e) => updatePollOption(index, e.target.value)}
                            placeholder={`Option ${index + 1}`}
                            className="input-modern"
                          />
                          {newPollOptions.length > 2 && (
                            <Button
                              type="button"
                              variant="outline"
                              size="sm"
                              onClick={() => removePollOption(index)}
                              className="w-10 h-10 flex-shrink-0"
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
                        className="btn-gradient-success"
                      >
                        + Ajouter une option
                      </Button>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                      <label className="block text-sm font-semibold mb-3 text-slate-700">
                        Minuteur (optionnel, en secondes)
                      </label>
                      <Input
                        type="number"
                        value={timerDuration}
                        onChange={(e) => setTimerDuration(e.target.value)}
                        placeholder="ex: 60"
                        className="input-modern"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-semibold mb-3 text-slate-700">
                        Affichage des résultats
                      </label>
                      <div className="flex items-center space-x-3 h-10">
                        <Switch
                          checked={showResultsRealTime}
                          onCheckedChange={setShowResultsRealTime}
                        />
                        <span className="text-sm text-slate-600">
                          {showResultsRealTime ? "Temps réel pour participants" : "Masqués pour participants"}
                        </span>
                      </div>
                    </div>
                  </div>

                  <Button 
                    onClick={createPoll}
                    disabled={!newPollQuestion || newPollOptions.some(opt => !opt.trim())}
                    className="w-full h-12 btn-gradient-primary"
                  >
                    <Sparkles className="w-5 h-5 mr-2" />
                    Créer le Sondage
                  </Button>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="report">
              <Card className="glass-card border-0 shadow-lg">
                <CardHeader className="bg-gradient-to-r from-red-500 to-pink-500 text-white rounded-t-xl">
                  <CardTitle className="flex items-center gap-2">
                    <FileText className="w-5 h-5" />
                    Rapport Final de la Réunion
                  </CardTitle>
                  <CardDescription className="text-red-100">
                    Téléchargez le rapport PDF contenant tous les résultats. 
                    <strong> Attention: Cette action supprimera définitivement toutes les données de la réunion.</strong>
                  </CardDescription>
                </CardHeader>
                <CardContent className="p-6 space-y-6">
                  <div className="glass-card bg-gradient-to-r from-yellow-50 to-orange-50 border border-yellow-200 p-6 rounded-xl">
                    <h3 className="font-bold text-yellow-800 mb-3 flex items-center gap-2">
                      <AlertCircle className="w-5 h-5" />
                      Important
                    </h3>
                    <ul className="text-sm text-yellow-700 space-y-2">
                      <li className="flex items-start gap-2">
                        <span className="w-1.5 h-1.5 bg-yellow-600 rounded-full mt-2 flex-shrink-0"></span>
                        Le rapport PDF contiendra la liste des participants approuvés
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="w-1.5 h-1.5 bg-yellow-600 rounded-full mt-2 flex-shrink-0"></span>
                        Tous les résultats de sondages avec votes et pourcentages
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="w-1.5 h-1.5 bg-yellow-600 rounded-full mt-2 flex-shrink-0"></span>
                        Une fois téléchargé, toutes les données seront supprimées
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="w-1.5 h-1.5 bg-yellow-600 rounded-full mt-2 flex-shrink-0"></span>
                        Cette action est irréversible
                      </li>
                    </ul>
                  </div>

                  <div className="glass-card bg-gradient-to-r from-blue-50 to-cyan-50 border border-blue-200 p-6 rounded-xl">
                    <h3 className="font-bold text-blue-800 mb-3 flex items-center gap-2">
                      <BarChart3 className="w-5 h-5" />
                      Résumé de la Réunion
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm text-blue-700">
                      <div className="text-center">
                        <div className="text-2xl font-bold text-blue-600">
                          {participants.filter(p => p.approval_status === 'approved').length}
                        </div>
                        <div>Participants approuvés</div>
                      </div>
                      <div className="text-center">
                        <div className="text-2xl font-bold text-blue-600">{polls.length}</div>
                        <div>Sondages créés</div>
                      </div>
                      <div className="text-center">
                        <div className="text-2xl font-bold text-blue-600">
                          {polls.filter(p => p.status === 'closed').length}
                        </div>
                        <div>Sondages fermés</div>
                      </div>
                    </div>
                  </div>

                  <Button 
                    onClick={downloadReport}
                    className="w-full h-14 btn-gradient-danger text-lg font-bold"
                  >
                    <Download className="w-6 h-6 mr-2" />
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

  // Participant Dashboard Component - Enhanced with ALL polls display
  const ParticipantDashboard = () => {
    const [status, setStatus] = useState("pending");
    const [polls, setPolls] = useState([]);
    const [votedPolls, setVotedPolls] = useState(new Set());

    useEffect(() => {
      if (participant) {
        checkParticipantStatus();
        loadPolls();
        
        // Set up polling for participant status and polls
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
        // Show ALL polls (active, closed, draft) to participants
        setPolls(response.data);
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
        
        // Recharger les sondages pour obtenir les résultats
        loadPolls();
      } catch (error) {
        console.error("Error submitting vote:", error);
        alert("Erreur lors du vote: " + (error.response?.data?.detail || "Erreur inconnue"));
      }
    };

    if (status === "pending") {
      return (
        <div className="min-h-screen bg-gradient-to-br from-yellow-50 via-orange-50 to-red-50 bg-pattern-dots flex items-center justify-center p-4">
          <Card className="glass-card-strong w-full max-w-md border-0 shadow-2xl">
            <CardContent className="text-center py-12">
              <div className="w-16 h-16 bg-gradient-to-br from-yellow-400 to-orange-500 rounded-full flex items-center justify-center mx-auto mb-6">
                <Clock className="w-8 h-8 text-white" />
              </div>
              <h2 className="text-2xl font-bold mb-4 gradient-text">En attente d'approbation</h2>
              <p className="text-slate-600 mb-6">
                Votre demande de participation est en cours d'examen par l'organisateur.
              </p>
              <div className="glass-card p-4 bg-gradient-to-r from-slate-50 to-gray-50">
                <p className="text-sm text-slate-700">
                  <strong>Réunion:</strong> {meeting?.title}<br />
                  <strong>Participant:</strong> {participant?.name}
                </p>
              </div>
            </CardContent>
          </Card>
        </div>
      );
    }

    if (status === "rejected") {
      return (
        <div className="min-h-screen bg-gradient-to-br from-red-50 via-pink-50 to-rose-50 bg-pattern-dots flex items-center justify-center p-4">
          <Card className="glass-card-strong w-full max-w-md border-0 shadow-2xl">
            <CardContent className="text-center py-12">
              <div className="w-16 h-16 bg-gradient-to-br from-red-500 to-pink-600 rounded-full flex items-center justify-center mx-auto mb-6">
                <AlertCircle className="w-8 h-8 text-white" />
              </div>
              <h2 className="text-2xl font-bold mb-4 text-red-600">Accès refusé</h2>
              <p className="text-slate-600 mb-6">
                Votre demande de participation a été refusée par l'organisateur.
              </p>
              <Button onClick={() => setCurrentView("home")} className="btn-gradient-primary">
                Retour à l'accueil
              </Button>
            </CardContent>
          </Card>
        </div>
      );
    }

    return (
      <div className="min-h-screen bg-gradient-to-br from-green-50 via-emerald-50 to-teal-50 bg-pattern-dots p-4">
        <div className="max-w-4xl mx-auto">
          {/* Header */}
          <Card className="glass-card-strong mb-8 border-0 shadow-xl">
            <CardHeader className="bg-gradient-to-r from-emerald-500 to-teal-600 text-white rounded-t-2xl">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 bg-white bg-opacity-20 rounded-xl flex items-center justify-center">
                    <CheckCircle className="w-6 h-6" />
                  </div>
                  <div>
                    <CardTitle className="text-xl font-bold">{meeting?.title}</CardTitle>
                    <CardDescription className="text-emerald-100">
                      Participant: {participant?.name} - Statut: Approuvé
                    </CardDescription>
                  </div>
                </div>
              </div>
            </CardHeader>
          </Card>

          <div className="space-y-6">
            {polls.map((poll) => {
              const hasVoted = votedPolls.has(poll.id);
              const canVote = poll.status === "active" && !hasVoted;
              const showResults = hasVoted || (poll.show_results_real_time && poll.status !== "draft");
              
              return (
                <Card key={poll.id} className="glass-card border-0 shadow-lg">
                  <CardHeader className={`rounded-t-xl text-white ${
                    poll.status === "active" ? "bg-gradient-to-r from-green-500 to-emerald-600" :
                    poll.status === "closed" ? "bg-gradient-to-r from-gray-500 to-slate-600" :
                    "bg-gradient-to-r from-blue-500 to-indigo-600"
                  }`}>
                    <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                      <CardTitle className="text-lg">{poll.question}</CardTitle>
                      <div className="flex items-center gap-2">
                        {poll.status === "active" && (
                          <Badge className="bg-white bg-opacity-20 text-white">
                            <Clock className="w-3 h-3 mr-1" />
                            En cours
                          </Badge>
                        )}
                        {poll.status === "closed" && (
                          <Badge className="bg-white bg-opacity-20 text-white">
                            Fermé
                          </Badge>
                        )}
                        {poll.status === "draft" && (
                          <Badge className="bg-white bg-opacity-20 text-white">
                            À venir
                          </Badge>
                        )}
                      </div>
                    </div>
                    {canVote && (
                      <CardDescription className="text-green-100 font-medium">
                        🔒 Votez pour voir les résultats
                      </CardDescription>
                    )}
                    {hasVoted && (
                      <CardDescription className="text-green-100 font-medium">
                        ✅ Vous avez voté - Résultats {poll.show_results_real_time ? "en temps réel" : "finaux"}
                      </CardDescription>
                    )}
                    {!canVote && !hasVoted && poll.status !== "active" && (
                      <CardDescription className="text-gray-100">
                        {poll.status === "closed" ? "Sondage terminé" : "Sondage pas encore lancé"}
                      </CardDescription>
                    )}
                  </CardHeader>
                  <CardContent className="p-6">
                    {canVote ? (
                      <div className="space-y-3">
                        {poll.options.map((option) => (
                          <Button
                            key={option.id}
                            variant="outline"
                            className="w-full justify-start h-12 vote-option"
                            onClick={() => submitVote(poll.id, option.id)}
                          >
                            <div className="flex items-center gap-3">
                              <div className="w-6 h-6 rounded-full border-2 border-slate-300"></div>
                              <span className="font-medium">{option.text}</span>
                            </div>
                          </Button>
                        ))}
                        <div className="mt-6 glass-card bg-gradient-to-r from-blue-50 to-cyan-50 border border-blue-200 p-4 rounded-xl">
                          <p className="text-sm text-blue-700 flex items-center gap-2">
                            <Shield className="w-4 h-4" />
                            <span className="font-semibold">Vote secret:</span> 
                            Les résultats {poll.show_results_real_time ? "s'affichent" : "ne s'affichent pas"} en temps réel
                          </p>
                        </div>
                      </div>
                    ) : showResults ? (
                      <div className="space-y-4">
                        {poll.options.map((option) => {
                          const totalVotes = poll.options.reduce((sum, opt) => sum + opt.votes, 0);
                          const percentage = totalVotes > 0 ? (option.votes / totalVotes) * 100 : 0;
                          
                          return (
                            <div key={option.id} className="space-y-2">
                              <div className="flex justify-between text-sm">
                                <span className="font-medium">{option.text}</span>
                                <span className="font-bold text-slate-600">
                                  {option.votes} votes ({percentage.toFixed(1)}%)
                                </span>
                              </div>
                              <Progress value={percentage} className="h-3 progress-animated" />
                            </div>
                          );
                        })}
                        {hasVoted && (
                          <div className="mt-4 glass-card bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200 p-4 rounded-xl">
                            <p className="text-sm text-green-700 flex items-center gap-2">
                              <CheckCircle className="w-4 h-4" />
                              <span className="font-semibold">Vote enregistré!</span> 
                              Les résultats se mettent à jour automatiquement
                            </p>
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="text-center py-8">
                        <Shield className="w-12 h-12 text-slate-300 mx-auto mb-4" />
                        <p className="text-slate-500">
                          {poll.status === "draft" ? "Ce sondage n'a pas encore été lancé" : 
                           "Les résultats seront affichés après la fin du sondage"}
                        </p>
                      </div>
                    )}
                  </CardContent>
                </Card>
              );
            })}

            {polls.length === 0 && (
              <Card className="glass-card border-0 shadow-lg">
                <CardContent className="text-center py-12">
                  <Vote className="w-16 h-16 text-slate-300 mx-auto mb-4" />
                  <p className="text-slate-500 text-lg">Aucun sondage n'a encore été créé</p>
                  <p className="text-slate-400 text-sm mt-2">
                    Les sondages apparaîtront ici automatiquement
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
      console.log("WebSocket connected");
      setWs(websocket);
    };
    
    websocket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      console.log("WebSocket message:", data);
      
      // Handle real-time updates based on message type
      if (data.type === "participant_joined" || data.type === "participant_approved") {
        // Refresh participant list for organizer
        if (currentView === "organizer") {
          window.location.reload(); // Simple refresh for now
        }
      }
      
      if (data.type === "poll_started" || data.type === "poll_closed" || data.type === "vote_submitted") {
        // Refresh polls for both organizer and participants
        window.location.reload(); // Simple refresh for now
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