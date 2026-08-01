import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/client';
import type { AppRole, Profile } from '@/lib/types';

interface AuthContextType {
  user: User | null;
  session: Session | null;
  profile: Profile | null;
  role: AppRole | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<{ error: Error | null }>;
  signUp: (
    email: string,
    password: string,
    fullName: string
  ) => Promise<{
    data: { user: User | null; session: Session | null };
    error: Error | null;
  }>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [role, setRole] = useState<AppRole | null>(null);
  const [loading, setLoading] = useState(true);

  // Tracks which user's profile/role we've already loaded, so the
  // INITIAL_SESSION event and the getSession() fallback don't double-fetch.
  const loadedUserId = useRef<string | null>(null);

  const fetchUserData = async (userId: string) => {
    try {
      const { data: profileData } = await supabase
        .from('profiles')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle();

      setProfile(profileData ?? null);

      const { data: roleData } = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();

      setRole((roleData?.role as AppRole) ?? null);
    } catch (err) {
      console.error('User data error:', err);
      setProfile(null);
      setRole(null);
    }
  };

  useEffect(() => {
    let active = true;

    // Applies a session to state. Deliberately synchronous: see the warning
    // on the onAuthStateChange callback below.
    const applySession = (nextSession: Session | null) => {
      if (!active) return;

      setSession(nextSession);
      setUser(nextSession?.user ?? null);

      const nextUserId = nextSession?.user?.id ?? null;

      if (!nextUserId) {
        loadedUserId.current = null;
        setProfile(null);
        setRole(null);
      } else if (loadedUserId.current !== nextUserId) {
        loadedUserId.current = nextUserId;
        // Deferred to a fresh task so the Supabase auth lock — held for the
        // duration of this callback — is released before fetchUserData issues
        // its own queries. Awaiting them inline deadlocks the auth client,
        // which eventually fails the token refresh and wipes the session.
        setTimeout(() => {
          if (active) void fetchUserData(nextUserId);
        }, 0);
      }

      setLoading(false);
    };

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      // Must NOT be async and must NOT await any supabase.* call.
      (event, currentSession) => {
        // TEMPORARY DIAGNOSTIC — remove once the logout issue is settled.
        console.log('[auth]', event, currentSession ? 'session' : 'NO SESSION');
        applySession(currentSession);
      }
    );

    // Fallback in case INITIAL_SESSION never arrives.
    supabase.auth.getSession().then(({ data: { session: initialSession } }) => {
      applySession(initialSession);
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  const signIn = async (email: string, password: string) => {
    return await supabase.auth.signInWithPassword({ email, password });
  };

  const signUp = async (email: string, password: string, fullName: string) => {
    return await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { full_name: fullName },
      },
    });
  };

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        session,
        profile,
        role,
        loading,
        signIn,
        signUp,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
