import { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Boxes,
  BarChart3,
  Bell,
  ShieldCheck,
  Users,
  History,
  FileText,
  Sparkles,
  Menu,
  X,
  Mail,
  Phone,
  MapPin,
  ArrowRight,
  Check,
  CalendarClock,
  MessageCircle,
  Factory,
  GraduationCap,
  Store,
  Warehouse,
  UtensilsCrossed,
  Pill,
  Wrench,
  Building2,
  Sun,
  Moon,
  Zap,
  Layers,
  Globe,
  Smartphone,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent } from '@/components/ui/card';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { useToast } from '@/hooks/use-toast';
import { useTheme } from '@/contexts/ThemeContext';
import { CONTACT } from '@/config/contact';

const NAV_LINKS = [
  { label: 'Features', href: '#features' },
  { label: 'Industries', href: '#industries' },
  { label: 'How it works', href: '#how' },
  { label: 'Contact', href: '#demo' },
];

const FEATURES = [
  {
    icon: Boxes,
    title: 'Real-time Inventory',
    body: 'Track every item, batch and variant with instant updates across every location.',
  },
  {
    icon: History,
    title: 'Movement History',
    body: 'Every in, out and transfer is logged automatically — full accountability, zero paperwork.',
  },
  {
    icon: BarChart3,
    title: 'Smart Reports',
    body: 'Beautiful, exportable PDF and CSV reports for owners, managers and auditors.',
  },
  {
    icon: Bell,
    title: 'Low-stock Alerts',
    body: 'Get notified the moment an item drops below its threshold so you never run out.',
  },
  {
    icon: Users,
    title: 'Role-based Access',
    body: 'Separate roles for owners, managers and floor staff so the right people see the right things.',
  },
  {
    icon: Layers,
    title: 'Categories & Variants',
    body: 'Group items by category, size, batch or any custom attribute your business needs.',
  },
  {
    icon: ShieldCheck,
    title: 'Secure Cloud Storage',
    body: 'Your data is safe in the cloud with automatic backups and enterprise-grade security.',
  },
  {
    icon: Smartphone,
    title: 'Works Anywhere',
    body: 'Use it on any laptop, tablet or phone — no installation, no setup headaches.',
  },
  {
    icon: Zap,
    title: 'Fast Onboarding',
    body: 'We configure the system for your business and train your team — usually within a week.',
  },
];

const INDUSTRIES = [
  {
    id: 'schools',
    icon: GraduationCap,
    title: 'Schools',
    tagline: 'Uniforms, books & school stores',
    features: [
      'Issue uniforms & sweaters to students',
      'Track sweater numbers and sizes',
      'Storekeeper & supervisor roles',
      'Term-by-term issuance reports',
    ],
  },
  {
    id: 'factories',
    icon: Factory,
    title: 'Factories',
    tagline: 'Raw materials & finished goods',
    features: [
      'Raw material and finished goods tracking',
      'Batch and lot management',
      'Production-line consumption logs',
      'Waste & yield reporting',
    ],
  },
  {
    id: 'retail',
    icon: Store,
    title: 'Retail Shops',
    tagline: 'Fast-moving consumer goods',
    features: [
      'Barcode-friendly product catalog',
      'Multi-branch stock visibility',
      'Sales-linked stock deductions',
      'Reorder point alerts',
    ],
  },
  {
    id: 'warehouses',
    icon: Warehouse,
    title: 'Warehouses',
    tagline: 'Distribution & logistics',
    features: [
      'Bin, rack and location tracking',
      'Stock transfers between warehouses',
      'Goods received & dispatch notes',
      'Inbound / outbound reports',
    ],
  },
  {
    id: 'restaurants',
    icon: UtensilsCrossed,
    title: 'Restaurants & Bars',
    tagline: 'Ingredients & bar stock',
    features: [
      'Ingredient-level tracking',
      'Recipe-based consumption',
      'Daily bar reconciliation',
      'Wastage & shrinkage reports',
    ],
  },
  {
    id: 'pharmacies',
    icon: Pill,
    title: 'Pharmacies & Clinics',
    tagline: 'Medicines & supplies',
    features: [
      'Expiry-date tracking',
      'Batch numbers & suppliers',
      'Controlled-item logs',
      'Prescription-linked deductions',
    ],
  },
  {
    id: 'workshops',
    icon: Wrench,
    title: 'Workshops & Garages',
    tagline: 'Spare parts & tools',
    features: [
      'Spare parts catalog',
      'Job-card linked consumption',
      'Tool check-in / check-out',
      'Supplier & purchase logs',
    ],
  },
  {
    id: 'offices',
    icon: Building2,
    title: 'Offices & NGOs',
    tagline: 'Assets & consumables',
    features: [
      'Office asset register',
      'Consumables tracking',
      'Department-level issuance',
      'Donor / project reports',
    ],
  },
];

const STEPS = [
  {
    title: 'Book a demo',
    body: 'Tell us about your business and we will set up a personalised walkthrough.',
  },
  {
    title: 'We customise your system',
    body: 'Categories, items and staff accounts are pre-loaded to match how you actually work.',
  },
  {
    title: 'Train your team',
    body: 'A short hands-on session so managers and floor staff are ready day one.',
  },
  {
    title: 'Go live & grow',
    body: 'Start tracking, issuing and reporting from any device, any time.',
  },
];

const BENEFITS = [
  'No more lost stock or missing records',
  'Cut stock counts from days to minutes',
  'Clear accountability across every role',
  'Instant PDF reports for meetings & audits',
  'Works on any laptop, tablet or phone',
  'Secure cloud storage with automatic backups',
];

const INDUSTRY_OPTIONS = INDUSTRIES.map((i) => ({ value: i.id, label: i.title }));

export default function Landing() {
  const { toast } = useToast();
  const { theme, toggleTheme } = useTheme();
  const demoRef = useRef<HTMLDivElement | null>(null);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [activeIndustry, setActiveIndustry] = useState<string>('schools');
  const [form, setForm] = useState({
    name: '',
    business: '',
    industry: '',
    email: '',
    phone: '',
    role: '',
    message: '',
  });

  const activeIndustryData = useMemo(
    () => INDUSTRIES.find((i) => i.id === activeIndustry) ?? INDUSTRIES[0],
    [activeIndustry],
  );

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  useEffect(() => {
    if (window.location.hash) {
      const id = window.location.hash.slice(1);
      requestAnimationFrame(() => {
        document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    }
  }, []);

  const scrollToDemo = (industryId?: string) => {
    if (industryId) setForm((f) => ({ ...f, industry: industryId }));
    demoRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    setMobileOpen(false);
  };

  const validate = () => {
    if (!form.name.trim() || !form.business.trim() || !form.phone.trim()) {
      toast({
        title: 'A few details missing',
        description: 'Please share at least your name, business and phone number.',
        variant: 'destructive',
      });
      return false;
    }
    return true;
  };

  const buildMessage = () => {
    const industryLabel =
      INDUSTRY_OPTIONS.find((o) => o.value === form.industry)?.label ?? form.industry;
    return [
      `Hello Cunga Stock team,`,
      ``,
      `I would like to book a demo of your inventory management system.`,
      ``,
      `Name: ${form.name}`,
      `Business: ${form.business}`,
      industryLabel && `Industry: ${industryLabel}`,
      form.role && `Role: ${form.role}`,
      form.email && `Email: ${form.email}`,
      `Phone: ${form.phone}`,
      form.message && ``,
      form.message && `Message: ${form.message}`,
    ]
      .filter(Boolean)
      .join('\n');
  };

  const sendWhatsApp = () => {
    if (!validate()) return;
    const url = `https://wa.me/${CONTACT.whatsappNumber}?text=${encodeURIComponent(buildMessage())}`;
    window.open(url, '_blank', 'noopener,noreferrer');
    toast({
      title: 'Opening WhatsApp',
      description: 'Send the pre-filled message and we will get back to you shortly.',
    });
  };

  const sendEmail = () => {
    if (!validate()) return;
    const subject = `Demo request — ${form.business}`;
    const body = buildMessage();
    // Open Gmail web compose in a new tab — pre-filled, one click to send.
    const gmailUrl = `https://mail.google.com/mail/?view=cm&fs=1&to=${encodeURIComponent(
      CONTACT.email,
    )}&su=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    window.open(gmailUrl, '_blank', 'noopener,noreferrer');
    toast({
      title: 'Email ready to send',
      description: 'Your Gmail is open with everything filled in — just click Send.',
    });
  };

  return (
    <div className="min-h-screen bg-background text-foreground overflow-x-hidden">
      {/* NAV */}
      <header
        className={`fixed top-0 inset-x-0 z-50 transition-all duration-300 ${
          scrolled
            ? 'bg-background/80 backdrop-blur-xl border-b border-border shadow-sm'
            : 'bg-transparent'
        }`}
      >
        <div className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16 sm:h-20 gap-2">
            <a href="#top" className="flex items-center gap-2 sm:gap-3 min-w-0">
              <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-white shadow-md overflow-hidden p-1 flex items-center justify-center flex-shrink-0">
                <img src="/cunga-logo-nobg.png" alt="Cunga Stock" className="w-full h-full object-contain" />
              </div>
              <div className="leading-tight min-w-0">
                <div className="font-bold text-sm sm:text-lg truncate">Cunga Stock</div>
                <div className="hidden sm:block text-[10px] sm:text-xs text-muted-foreground -mt-0.5 truncate">
                  Inventory Management, Your Way
                </div>
              </div>
            </a>

            <nav className="hidden md:flex items-center gap-8">
              {NAV_LINKS.map((l) => (
                <a
                  key={l.href}
                  href={l.href}
                  className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
                >
                  {l.label}
                </a>
              ))}
            </nav>

            <div className="hidden md:flex items-center gap-2">
              <Button
                variant="ghost"
                size="icon"
                onClick={toggleTheme}
                aria-label="Toggle theme"
                title={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
              >
                {theme === 'dark' ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
              </Button>
              <Link to="/auth">
                <Button variant="ghost" size="sm">
                  Login
                </Button>
              </Link>
              <Button
                size="sm"
                onClick={() => scrollToDemo()}
                className="gradient-primary text-white border-0 shadow-md"
              >
                Book a Demo
                <ArrowRight className="h-4 w-4" />
              </Button>
            </div>

            <div className="md:hidden flex items-center gap-1">
              <Button
                variant="ghost"
                size="icon"
                onClick={toggleTheme}
                aria-label="Toggle theme"
              >
                {theme === 'dark' ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
              </Button>
              <button
                className="p-2 rounded-md hover:bg-muted"
                onClick={() => setMobileOpen((s) => !s)}
                aria-label="Toggle menu"
              >
                {mobileOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
              </button>
            </div>
          </div>

          {mobileOpen && (
            <div className="md:hidden pb-4 border-t border-border/60 animate-fade-in">
              <div className="flex flex-col gap-1 pt-3">
                {NAV_LINKS.map((l) => (
                  <a
                    key={l.href}
                    href={l.href}
                    onClick={() => setMobileOpen(false)}
                    className="px-3 py-2 rounded-md text-sm font-medium text-muted-foreground hover:text-foreground hover:bg-muted"
                  >
                    {l.label}
                  </a>
                ))}
                <div className="flex gap-2 mt-3 px-1">
                  <Link to="/auth" className="flex-1">
                    <Button variant="outline" className="w-full">
                      Login
                    </Button>
                  </Link>
                  <Button
                    className="flex-1 gradient-primary text-white border-0"
                    onClick={() => scrollToDemo()}
                  >
                    Book Demo
                  </Button>
                </div>
              </div>
            </div>
          )}
        </div>
      </header>

      {/* HERO */}
      <section id="top" className="relative pt-24 sm:pt-32 lg:pt-36 pb-16 sm:pb-24 lg:pb-28 overflow-hidden">
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute -top-24 -left-24 w-72 sm:w-[28rem] h-72 sm:h-[28rem] bg-primary/20 rounded-full blur-3xl" />
          <div className="absolute top-1/3 -right-24 w-72 sm:w-[28rem] h-72 sm:h-[28rem] bg-accent/20 rounded-full blur-3xl" />
          <div className="absolute bottom-0 left-1/3 w-72 sm:w-96 h-72 sm:h-96 bg-primary/10 rounded-full blur-3xl" />
        </div>

        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col items-center text-center max-w-4xl mx-auto animate-fade-in">
            <div className="inline-flex items-center gap-2 px-3 sm:px-4 py-1.5 rounded-full bg-primary/10 border border-primary/20 text-primary text-[11px] sm:text-sm font-medium mb-5 sm:mb-6 max-w-full">
              <Sparkles className="h-3.5 w-3.5 flex-shrink-0" />
              <span className="truncate">One inventory system, tailored to your business</span>
            </div>

            <h1 className="text-3xl sm:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.15]">
              Stock management for
              <span className="block mt-1 sm:mt-2 bg-clip-text text-transparent bg-gradient-to-r from-primary to-accent">
                every kind of business
              </span>
            </h1>

            <p className="mt-5 sm:mt-6 text-sm sm:text-lg text-muted-foreground max-w-2xl px-2 sm:px-0">
              Cunga Stock is a modern inventory management system for factories, schools, retail
              shops, warehouses, restaurants and more. We configure it to match how <em>your</em>{' '}
              business actually works — not the other way around.
            </p>

            <div className="mt-7 sm:mt-8 flex flex-col sm:flex-row gap-3 w-full sm:w-auto">
              <Button
                size="lg"
                onClick={() => scrollToDemo()}
                className="gradient-primary text-white border-0 shadow-glow text-sm sm:text-base h-11 sm:h-12 px-6 sm:px-8 w-full sm:w-auto"
              >
                <CalendarClock className="h-5 w-5" />
                Book a Free Demo
              </Button>
              <Button
                size="lg"
                variant="outline"
                asChild
                className="text-sm sm:text-base h-11 sm:h-12 px-6 sm:px-8 w-full sm:w-auto"
              >
                <a href="#industries">
                  See your industry
                  <ArrowRight className="h-5 w-5" />
                </a>
              </Button>
            </div>

            <div className="mt-8 sm:mt-10 flex flex-wrap justify-center gap-x-6 sm:gap-x-8 gap-y-3 text-xs sm:text-sm text-muted-foreground">
              <div className="flex items-center gap-2">
                <ShieldCheck className="h-4 w-4 text-primary" />
                Secure cloud storage
              </div>
              <div className="flex items-center gap-2">
                <Users className="h-4 w-4 text-primary" />
                Role-based accounts
              </div>
              <div className="flex items-center gap-2">
                <Globe className="h-4 w-4 text-primary" />
                Any device, any time
              </div>
            </div>
          </div>

          {/* Mock preview card */}
          <div className="mt-12 sm:mt-16 lg:mt-20 max-w-5xl mx-auto animate-slide-up">
            <div className="relative">
              <div className="absolute -inset-2 sm:-inset-4 bg-gradient-to-r from-primary/30 to-accent/30 rounded-3xl blur-2xl opacity-60" />
              <div className="relative rounded-xl sm:rounded-2xl border border-border bg-card shadow-xl overflow-hidden">
                <div className="flex items-center gap-2 px-3 sm:px-4 py-2 sm:py-3 border-b border-border bg-muted/50">
                  <div className="flex gap-1 sm:gap-1.5">
                    <span className="w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-full bg-red-400" />
                    <span className="w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-full bg-yellow-400" />
                    <span className="w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-full bg-green-400" />
                  </div>
                  <div className="mx-auto text-[10px] sm:text-xs text-muted-foreground font-medium truncate">
                    cungastock.com / dashboard
                  </div>
                </div>
                <div className="p-4 sm:p-6 lg:p-10 bg-gradient-to-br from-background to-muted/40">
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-4 lg:gap-6">
                    {[
                      { label: 'Total Items', value: '1,248', tone: 'primary', icon: Boxes },
                      { label: 'Movements this week', value: '312', tone: 'accent', icon: History },
                      { label: 'Low stock', value: '7', tone: 'warning', icon: Bell },
                    ].map((s) => (
                      <div key={s.label} className="rounded-lg sm:rounded-xl bg-card border border-border p-4 sm:p-5 shadow-sm">
                        <div className="flex items-center justify-between gap-2">
                          <span className="text-[10px] sm:text-xs uppercase tracking-wide text-muted-foreground truncate">
                            {s.label}
                          </span>
                          <s.icon className="h-4 w-4 text-muted-foreground flex-shrink-0" />
                        </div>
                        <div className="mt-2 sm:mt-3 text-2xl sm:text-3xl font-bold">{s.value}</div>
                        <div className="mt-2 h-1.5 rounded-full bg-muted overflow-hidden">
                          <div
                            className={`h-full rounded-full ${
                              s.tone === 'primary'
                                ? 'bg-primary w-4/5'
                                : s.tone === 'accent'
                                ? 'bg-accent w-3/5'
                                : 'bg-warning w-1/5'
                            }`}
                          />
                        </div>
                      </div>
                    ))}
                  </div>

                  <div className="mt-4 sm:mt-6 rounded-lg sm:rounded-xl bg-card border border-border overflow-hidden">
                    <div className="px-4 sm:px-5 py-2.5 sm:py-3 border-b border-border flex items-center justify-between">
                      <div className="font-semibold text-xs sm:text-sm">Recent Movements</div>
                      <div className="text-[10px] sm:text-xs text-muted-foreground">Today</div>
                    </div>
                    <div className="divide-y divide-border">
                      {[
                        { name: 'Raw Cotton', item: 'IN · 250 kg', time: '09:14' },
                        { name: 'Sweater #124', item: 'ISSUED · to J. Okello', time: '09:22' },
                        { name: 'Paracetamol 500mg', item: 'OUT · 30 tabs', time: '09:38' },
                      ].map((r) => (
                        <div key={r.name} className="flex items-center justify-between gap-3 px-4 sm:px-5 py-2.5 sm:py-3 text-sm">
                          <div className="flex items-center gap-2.5 sm:gap-3 min-w-0">
                            <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-primary/10 text-primary flex items-center justify-center flex-shrink-0">
                              <Boxes className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                            </div>
                            <div className="min-w-0">
                              <div className="font-medium text-xs sm:text-sm truncate">{r.name}</div>
                              <div className="text-[10px] sm:text-xs text-muted-foreground truncate">{r.item}</div>
                            </div>
                          </div>
                          <div className="text-[10px] sm:text-xs text-muted-foreground flex-shrink-0">{r.time}</div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FEATURES */}
      <section id="features" className="py-16 sm:py-20 lg:py-28 bg-muted/30 border-y border-border">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-2xl mx-auto">
            <div className="text-primary text-xs sm:text-sm font-semibold uppercase tracking-wide">
              Core features
            </div>
            <h2 className="mt-3 text-2xl sm:text-3xl lg:text-4xl font-bold">
              Everything a modern stockroom needs
            </h2>
            <p className="mt-4 text-sm sm:text-base text-muted-foreground">
              A powerful foundation that works out of the box — then we customise the workflows,
              categories and reports for your specific business.
            </p>
          </div>

          <div className="mt-10 sm:mt-14 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
            {FEATURES.map((f) => (
              <Card
                key={f.title}
                className="group border-border hover:border-primary/40 hover:shadow-lg transition-all duration-300"
              >
                <CardContent className="p-5 sm:p-6">
                  <div className="w-11 h-11 sm:w-12 sm:h-12 rounded-xl gradient-primary flex items-center justify-center shadow-md group-hover:scale-110 transition-transform">
                    <f.icon className="h-5 w-5 sm:h-6 sm:w-6 text-white" />
                  </div>
                  <h3 className="mt-4 sm:mt-5 text-base sm:text-lg font-semibold">{f.title}</h3>
                  <p className="mt-2 text-sm text-muted-foreground leading-relaxed">{f.body}</p>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* INDUSTRIES */}
      <section id="industries" className="py-16 sm:py-20 lg:py-28">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-2xl mx-auto">
            <div className="text-primary text-xs sm:text-sm font-semibold uppercase tracking-wide">
              Built for your industry
            </div>
            <h2 className="mt-3 text-2xl sm:text-3xl lg:text-4xl font-bold">
              Customised for how <em>you</em> work
            </h2>
            <p className="mt-4 text-sm sm:text-base text-muted-foreground">
              Pick your industry to see the workflows, fields and reports we tailor for
              businesses like yours. Don't see yours? We'll build it.
            </p>
          </div>

          {/* Industry chips — horizontally scrollable on mobile, wrapping on larger screens */}
          <div className="mt-8 sm:mt-10 -mx-4 sm:mx-0 px-4 sm:px-0 overflow-x-auto sm:overflow-visible">
            <div className="flex sm:flex-wrap sm:justify-center gap-2 sm:gap-3 min-w-max sm:min-w-0 pb-2 sm:pb-0">
              {INDUSTRIES.map((ind) => {
                const active = activeIndustry === ind.id;
                return (
                  <button
                    key={ind.id}
                    onClick={() => setActiveIndustry(ind.id)}
                    className={`inline-flex items-center gap-2 px-3 sm:px-4 py-2 rounded-full border text-xs sm:text-sm font-medium transition-all whitespace-nowrap flex-shrink-0 ${
                      active
                        ? 'bg-primary text-primary-foreground border-primary shadow-md'
                        : 'bg-card text-foreground border-border hover:border-primary/40 hover:bg-muted'
                    }`}
                  >
                    <ind.icon className="h-4 w-4" />
                    {ind.title}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Active industry detail */}
          <div className="mt-8 sm:mt-10 max-w-4xl mx-auto">
            <Card className="border-border shadow-lg overflow-hidden animate-fade-in" key={activeIndustryData.id}>
              <CardContent className="p-0">
                <div className="grid grid-cols-1 md:grid-cols-5">
                  <div className="md:col-span-2 gradient-primary text-white p-6 sm:p-8 flex flex-col justify-between gap-6">
                    <div>
                      <div className="w-12 h-12 sm:w-14 sm:h-14 rounded-2xl bg-white/15 backdrop-blur-sm flex items-center justify-center">
                        <activeIndustryData.icon className="h-6 w-6 sm:h-7 sm:w-7" />
                      </div>
                      <h3 className="mt-4 sm:mt-6 text-xl sm:text-2xl font-bold">{activeIndustryData.title}</h3>
                      <p className="mt-2 text-white/85 text-sm">{activeIndustryData.tagline}</p>
                    </div>
                    <Button
                      variant="secondary"
                      className="w-full bg-white text-primary hover:bg-white/90 text-xs sm:text-sm"
                      onClick={() => scrollToDemo(activeIndustryData.id)}
                    >
                      <CalendarClock className="h-4 w-4" />
                      <span className="truncate">
                        Book a demo for {activeIndustryData.title.toLowerCase()}
                      </span>
                    </Button>
                  </div>
                  <div className="md:col-span-3 p-6 sm:p-8">
                    <div className="text-[10px] sm:text-xs uppercase tracking-wide text-muted-foreground mb-3 sm:mb-4">
                      What we tailor for you
                    </div>
                    <ul className="space-y-3">
                      {activeIndustryData.features.map((f) => (
                        <li key={f} className="flex items-start gap-3">
                          <span className="mt-0.5 flex-shrink-0 w-6 h-6 rounded-full bg-primary/15 text-primary flex items-center justify-center">
                            <Check className="h-3.5 w-3.5" />
                          </span>
                          <span className="text-sm">{f}</span>
                        </li>
                      ))}
                    </ul>
                    <div className="mt-6 pt-6 border-t border-border">
                      <p className="text-xs text-muted-foreground">
                        Need something else? During onboarding we adjust fields, categories and
                        reports to match your exact workflow.
                      </p>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section id="how" className="py-16 sm:py-20 lg:py-28 bg-muted/30 border-y border-border">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-2xl mx-auto">
            <div className="text-primary text-xs sm:text-sm font-semibold uppercase tracking-wide">
              Getting started
            </div>
            <h2 className="mt-3 text-2xl sm:text-3xl lg:text-4xl font-bold">
              Up and running in four simple steps
            </h2>
          </div>

          <div className="mt-10 sm:mt-14 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
            {STEPS.map((s, i) => (
              <div key={s.title} className="relative">
                <div className="rounded-2xl border border-border bg-card p-5 sm:p-6 h-full hover:shadow-md transition-shadow">
                  <div className="w-10 h-10 sm:w-11 sm:h-11 rounded-xl gradient-primary text-white flex items-center justify-center font-bold shadow-md">
                    {i + 1}
                  </div>
                  <h3 className="mt-4 sm:mt-5 text-base sm:text-lg font-semibold">{s.title}</h3>
                  <p className="mt-2 text-sm text-muted-foreground leading-relaxed">{s.body}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* WHY */}
      <section id="why" className="py-16 sm:py-20 lg:py-28">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-10 sm:gap-12 lg:gap-20 items-center">
            <div>
              <div className="text-primary text-xs sm:text-sm font-semibold uppercase tracking-wide">
                Why Cunga
              </div>
              <h2 className="mt-3 text-2xl sm:text-3xl lg:text-4xl font-bold">
                Save time. Cut losses. Stay in control.
              </h2>
              <p className="mt-4 text-sm sm:text-base text-muted-foreground">
                Businesses using Cunga Stock spend less time hunting for records and more time
                running the show. Everything is one click away — from a single missing item to a
                full-quarter report.
              </p>

              <ul className="mt-6 sm:mt-8 space-y-3">
                {BENEFITS.map((b) => (
                  <li key={b} className="flex items-start gap-3">
                    <span className="mt-0.5 flex-shrink-0 w-5 h-5 rounded-full bg-primary/15 text-primary flex items-center justify-center">
                      <Check className="h-3 w-3" />
                    </span>
                    <span className="text-sm">{b}</span>
                  </li>
                ))}
              </ul>

              <div className="mt-8 sm:mt-10">
                <Button
                  size="lg"
                  onClick={() => scrollToDemo()}
                  className="gradient-primary text-white border-0 shadow-glow w-full sm:w-auto"
                >
                  <CalendarClock className="h-5 w-5" />
                  Book a Free Demo
                </Button>
              </div>
            </div>

            <div className="relative">
              <div className="absolute -inset-4 sm:-inset-6 bg-gradient-to-tr from-primary/20 to-accent/20 rounded-3xl blur-2xl" />
              <div className="relative grid grid-cols-2 gap-3 sm:gap-4">
                {[
                  { icon: Boxes, value: '100%', label: 'Digital record keeping' },
                  { icon: BarChart3, value: '5x', label: 'Faster stock audits' },
                  { icon: ShieldCheck, value: 'Zero', label: 'Lost paperwork' },
                  { icon: Users, value: 'Multi', label: 'User roles' },
                ].map((c) => (
                  <div
                    key={c.label}
                    className="rounded-xl sm:rounded-2xl border border-border bg-card p-4 sm:p-6 shadow-sm hover:shadow-md transition-shadow"
                  >
                    <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-lg bg-primary/10 text-primary flex items-center justify-center">
                      <c.icon className="h-4 w-4 sm:h-5 sm:w-5" />
                    </div>
                    <div className="mt-3 sm:mt-4 text-xl sm:text-3xl font-bold">{c.value}</div>
                    <div className="mt-1 text-xs sm:text-sm text-muted-foreground">{c.label}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* DEMO */}
      <section
        id="demo"
        ref={demoRef}
        className="py-16 sm:py-20 lg:py-28 bg-gradient-to-br from-primary/5 via-background to-accent/5 border-t border-border"
      >
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 lg:grid-cols-5 gap-8 lg:gap-10">
            <div className="lg:col-span-2 flex flex-col justify-between">
              <div>
                <div className="text-primary text-xs sm:text-sm font-semibold uppercase tracking-wide">
                  Book a Demo
                </div>
                <h2 className="mt-3 text-2xl sm:text-3xl lg:text-4xl font-bold">
                  Get a system built around your business
                </h2>
                <p className="mt-4 text-sm sm:text-base text-muted-foreground">
                  Accounts are only opened after a short onboarding call so we can tailor the
                  system to your industry. Share your details and we will reach out on WhatsApp or
                  email to schedule your walkthrough.
                </p>

                <div className="mt-8 space-y-4">
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 rounded-lg bg-primary/10 text-primary flex items-center justify-center flex-shrink-0">
                      <Phone className="h-5 w-5" />
                    </div>
                    <div>
                      <div className="text-xs uppercase text-muted-foreground tracking-wide">
                        Call us
                      </div>
                      <div className="font-medium">
                        <a href={`tel:+250${CONTACT.displayPhonePrimary.slice(1)}`} className="hover:text-primary transition-colors">
                          {CONTACT.displayPhonePrimary}
                        </a>
                        <span className="text-muted-foreground text-xs ml-2">(main)</span>
                      </div>
                      <div className="font-medium mt-1">
                        <a href={`tel:+250${CONTACT.displayPhoneSecondary.slice(1)}`} className="hover:text-primary transition-colors">
                          {CONTACT.displayPhoneSecondary}
                        </a>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 rounded-lg bg-primary/10 text-primary flex items-center justify-center flex-shrink-0">
                      <MessageCircle className="h-5 w-5" />
                    </div>
                    <div>
                      <div className="text-xs uppercase text-muted-foreground tracking-wide">
                        WhatsApp
                      </div>
                      <div className="font-medium">
                        <a
                          href={`https://wa.me/${CONTACT.whatsappNumber}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="hover:text-primary transition-colors"
                        >
                          {CONTACT.displayWhatsApp}
                        </a>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 rounded-lg bg-primary/10 text-primary flex items-center justify-center flex-shrink-0">
                      <Mail className="h-5 w-5" />
                    </div>
                    <div>
                      <div className="text-xs uppercase text-muted-foreground tracking-wide">
                        Email
                      </div>
                      <div className="font-medium">
                        <a href={`mailto:${CONTACT.email}`} className="hover:text-primary transition-colors">
                          {CONTACT.displayEmail}
                        </a>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 rounded-lg bg-primary/10 text-primary flex items-center justify-center flex-shrink-0">
                      <MapPin className="h-5 w-5" />
                    </div>
                    <div>
                      <div className="text-xs uppercase text-muted-foreground tracking-wide">
                        Based in
                      </div>
                      <div className="font-medium">{CONTACT.location}</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="lg:col-span-3">
              <Card className="border-border shadow-xl">
                <CardContent className="p-4 sm:p-6 lg:p-8">
                  <form
                    className="space-y-4 sm:space-y-5"
                    onSubmit={(e) => {
                      e.preventDefault();
                      sendWhatsApp();
                    }}
                  >
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label htmlFor="lp-name">Your Name *</Label>
                        <Input
                          id="lp-name"
                          value={form.name}
                          onChange={(e) => setForm({ ...form, name: e.target.value })}
                          placeholder="Jane Doe"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="lp-business">Business / Organisation *</Label>
                        <Input
                          id="lp-business"
                          value={form.business}
                          onChange={(e) => setForm({ ...form, business: e.target.value })}
                          placeholder="Acme Manufacturing Ltd"
                        />
                      </div>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label htmlFor="lp-industry">Industry</Label>
                        <Select
                          value={form.industry}
                          onValueChange={(v) => setForm({ ...form, industry: v })}
                        >
                          <SelectTrigger id="lp-industry">
                            <SelectValue placeholder="Select your industry" />
                          </SelectTrigger>
                          <SelectContent>
                            {INDUSTRY_OPTIONS.map((o) => (
                              <SelectItem key={o.value} value={o.value}>
                                {o.label}
                              </SelectItem>
                            ))}
                            <SelectItem value="other">Other</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="lp-role">Your Role</Label>
                        <Input
                          id="lp-role"
                          value={form.role}
                          onChange={(e) => setForm({ ...form, role: e.target.value })}
                          placeholder="Owner / Manager / Storekeeper"
                        />
                      </div>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label htmlFor="lp-phone">Phone / WhatsApp *</Label>
                        <Input
                          id="lp-phone"
                          value={form.phone}
                          onChange={(e) => setForm({ ...form, phone: e.target.value })}
                          placeholder="+250 788 980 607"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="lp-email">Email</Label>
                        <Input
                          id="lp-email"
                          type="email"
                          value={form.email}
                          onChange={(e) => setForm({ ...form, email: e.target.value })}
                          placeholder="you@business.com"
                        />
                      </div>
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor="lp-message">Anything specific you'd like to see?</Label>
                      <Textarea
                        id="lp-message"
                        value={form.message}
                        onChange={(e) => setForm({ ...form, message: e.target.value })}
                        placeholder="Tell us about your stock, team size, or any features you'd like customised..."
                        rows={4}
                      />
                    </div>

                    <div className="flex flex-col sm:flex-row gap-3 pt-2">
                      <Button
                        type="submit"
                        size="lg"
                        className="flex-1 gradient-primary text-white border-0 shadow-md"
                      >
                        <MessageCircle className="h-5 w-5" />
                        Send via WhatsApp
                      </Button>
                      <Button
                        type="button"
                        size="lg"
                        variant="outline"
                        className="flex-1"
                        onClick={sendEmail}
                      >
                        <Mail className="h-5 w-5" />
                        Send via Email
                      </Button>
                    </div>

                    <p className="text-xs text-muted-foreground text-center pt-2">
                      By submitting, you agree to be contacted by the Cunga Stock team to arrange
                      your demo.
                    </p>
                  </form>
                </CardContent>
              </Card>
            </div>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="bg-sidebar text-sidebar-foreground">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-12">
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-8">
            <div className="sm:col-span-2 md:col-span-2">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-white overflow-hidden p-1 flex items-center justify-center flex-shrink-0">
                  <img src="/cunga-logo-nobg.png" alt="Cunga Stock" className="w-full h-full object-contain" />
                </div>
                <div className="min-w-0">
                  <div className="font-bold text-base sm:text-lg">Cunga Stock</div>
                  <div className="text-xs opacity-70 truncate">Inventory Management, Your Way</div>
                </div>
              </div>
              <p className="mt-4 text-sm opacity-80 max-w-md">
                Cunga Stock is a modern inventory management system that adapts to your business
                — factories, schools, retailers, warehouses, restaurants and more.
              </p>
            </div>

            <div>
              <div className="text-xs uppercase tracking-wide opacity-60 mb-3">Product</div>
              <ul className="space-y-2 text-sm">
                {NAV_LINKS.map((l) => (
                  <li key={l.href}>
                    <a href={l.href} className="opacity-80 hover:opacity-100 hover:underline">
                      {l.label}
                    </a>
                  </li>
                ))}
                <li>
                  <Link to="/auth" className="opacity-80 hover:opacity-100 hover:underline">
                    Login
                  </Link>
                </li>
              </ul>
            </div>

            <div className="min-w-0">
              <div className="text-xs uppercase tracking-wide opacity-60 mb-3">Contact</div>
              <ul className="space-y-2 text-sm">
                <li className="flex items-center gap-2 opacity-80 flex-wrap">
                  <Phone className="h-4 w-4 flex-shrink-0" /> {CONTACT.displayPhonePrimary}
                  <span className="opacity-60 text-xs">(main)</span>
                </li>
                <li className="flex items-center gap-2 opacity-80">
                  <Phone className="h-4 w-4 flex-shrink-0" /> {CONTACT.displayPhoneSecondary}
                </li>
                <li className="flex items-center gap-2 opacity-80 flex-wrap">
                  <MessageCircle className="h-4 w-4 flex-shrink-0" /> {CONTACT.displayWhatsApp}
                  <span className="opacity-60 text-xs">(WhatsApp)</span>
                </li>
                <li className="flex items-center gap-2 opacity-80 min-w-0">
                  <Mail className="h-4 w-4 flex-shrink-0" />
                  <span className="truncate">{CONTACT.displayEmail}</span>
                </li>
                <li className="flex items-center gap-2 opacity-80">
                  <MapPin className="h-4 w-4 flex-shrink-0" /> {CONTACT.location}
                </li>
              </ul>
            </div>
          </div>

          <div className="mt-8 sm:mt-10 pt-6 border-t border-sidebar-border flex flex-col sm:flex-row items-center justify-between gap-2 sm:gap-3 text-xs opacity-70 text-center">
            <div>© {new Date().getFullYear()} Cunga Stock. All rights reserved.</div>
            <div>One system. Every business.</div>
          </div>
        </div>
      </footer>
    </div>
  );
}
