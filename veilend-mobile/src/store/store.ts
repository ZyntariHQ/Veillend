import { create } from 'zustand';

interface AppState {
  address: string | null;
  authToken: string | null;
  isPrivacyMode: boolean;
  setAddress: (address: string) => void;
  setAuthToken: (token: string) => void;
  togglePrivacyMode: () => void;
  logout: () => void;
}

export const useStore = create<AppState>((set) => ({
  address: null,
  authToken: null,
  isPrivacyMode: false,
  setAddress: (address) => set({ address }),
  setAuthToken: (token) => set({ authToken: token }),
  togglePrivacyMode: () => set((state) => ({ isPrivacyMode: !state.isPrivacyMode })),
  logout: () => set({ address: null, authToken: null, isPrivacyMode: false }),
}));
