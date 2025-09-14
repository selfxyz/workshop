"use client";

import React, { useState, useEffect, useMemo } from "react";
import { useRouter } from "next/navigation";
import { getUniversalLink } from "@selfxyz/core";
import {
  SelfQRcodeWrapper,
  SelfAppBuilder,
  type SelfApp,
} from "@selfxyz/qrcode";
import { ethers, getAddress } from "ethers";


export default function Home() {
  const router = useRouter();
  const [linkCopied, setLinkCopied] = useState(false);
  const [showToast, setShowToast] = useState(false);
  const [toastMessage, setToastMessage] = useState("");
  // Self app instance and universal link are memoized below
  const [walletAddress, setWalletAddress] = useState<string>("");
  const [walletError, setWalletError] = useState<string | null>(null);
  const [userId, setUserId] = useState<string>(ethers.ZeroAddress);
  // No status data on this page; it's handled on /status
  const [isMobile, setIsMobile] = useState(false);
  

  // Mobile / in-app detection and stable setup
  useEffect(() => {
    try {
      // Detect mobile / in-app webview to decide whether to show copy/open tools
      const ua = (typeof navigator !== "undefined" && navigator.userAgent) || "";
      const mobile = /(Android|iPhone|iPad|iPod|Mobile|Windows Phone)/i.test(ua) ||
        // @ts-ignore
        (typeof window !== "undefined" && !!(window as any).ReactNativeWebView);
      setIsMobile(!!mobile);
    } catch (error) {
      console.error("Failed to initialize Self app:", error);
    }
  }, []);

  // Wallet accounts detection
  useEffect(() => {
    const eth = (typeof window !== "undefined" && (window as any).ethereum) || null;
    if (!eth) return;
    const onAccounts = (accounts: string[]) => {
      try {
        if (accounts && accounts[0]) {
          const a = getAddress(accounts[0]);
          setWalletAddress(a);
          setUserId(a);
          setWalletError(null);
        }
      } catch {
        setWalletError("Invalid wallet address");
      }
    };
    eth.request?.({ method: "eth_accounts" }).then(onAccounts).catch(() => {});
    eth.on?.("accountsChanged", onAccounts);
    return () => { try { eth.removeListener?.("accountsChanged", onAccounts); } catch {} };
  }, []);

  async function connectWallet() {
    try {
      const eth = (window as any).ethereum;
      if (!eth) { setWalletError("No wallet found in this browser"); return; }
      const accounts = await eth.request({ method: "eth_requestAccounts" });
      if (accounts && accounts[0]) {
        const a = getAddress(accounts[0]);
        setWalletAddress(a);
        setUserId(a);
        setWalletError(null);
      }
    } catch (e: any) {
      setWalletError(e?.message || "Failed to connect wallet");
    }
  }

  const endpointAddr = (process.env.NEXT_PUBLIC_SOURCE_CONTRACT || "").toString();
  const selfApp: SelfApp | null = useMemo(() => {
    try {
      if (!endpointAddr) {
        console.warn("Missing endpoint address: set NEXT_PUBLIC_SOURCE_CONTRACT in app/.env");
        return null;
      }
      return new SelfAppBuilder({
        version: 2,
        appName: process.env.NEXT_PUBLIC_SELF_APP_NAME || "Self LayerZero Demo",
        scope: process.env.NEXT_PUBLIC_SELF_SCOPE || "self-workshop",
        endpoint: endpointAddr,
        logoBase64: "https://i.postimg.cc/mrmVf9hm/self.png",
        userId: userId,
        endpointType: "celo",
        userIdType: "hex",
        userDefinedData: "Self verification result bridging to Base Mainnet",
        disclosures: {
          minimumAge: 18,
          nationality: true,
          gender: true,
        }
      }).build();
    } catch (e) {
      console.error("Failed to initialize Self app:", e);
      return null;
    }
  }, [endpointAddr, userId]);

  const universalLink = useMemo(() => (selfApp ? getUniversalLink(selfApp) : ""), [selfApp]);

  // No status polling on QR page; polling happens on /status

  const displayToast = (message: string) => {
    setToastMessage(message);
    setShowToast(true);
    setTimeout(() => setShowToast(false), 3000);
  };

  const copyToClipboard = () => {
    if (!universalLink) return;

    navigator.clipboard
      .writeText(universalLink)
      .then(() => {
        setLinkCopied(true);
        displayToast("Universal link copied to clipboard!");
        setTimeout(() => setLinkCopied(false), 2000);
      })
      .catch((err) => {
        console.error("Failed to copy text: ", err);
        displayToast("Failed to copy link");
      });
  };

  const openSelfApp = () => {
    if (!universalLink) return;

    window.open(universalLink, "_blank");
    displayToast("Opening Self App...");
  };

  const handleSuccessfulVerification = () => {
    displayToast("Verification successful! Opening status…");
    const u = encodeURIComponent(userId);
    setTimeout(() => router.push(`/status?user=${u}`), 800);
  };

  // Address sanitize helper (pads/truncates hex to 20 bytes and checks checksum)
  function sanitizeHexAddress(raw: string): { value?: string; warning?: string; error?: string } {
    let s = raw.trim();
    if (!s) return { value: ethers.ZeroAddress };
    if (s.startsWith("0x") || s.startsWith("0X")) s = s.slice(2);
    if (!/^[0-9a-fA-F]*$/.test(s)) return { error: "Invalid characters: address must be hex" };
    let warning: string | undefined;
    if (s.length < 40) { warning = "Padded with zeros to 20 bytes"; s = s.padStart(40, "0"); }
    else if (s.length > 40) { warning = "Truncated to last 20 bytes"; s = s.slice(-40); }
    const candidate = "0x" + s;
    try { return { value: getAddress(candidate), warning }; } catch { return { error: "Not a valid address after normalization" }; }
  }

  function onAddressChange(v: string) {
    setInputAddress(v);
    const { value, warning, error } = sanitizeHexAddress(v);
    if (error) { setAddrError(error); setNextUserId(null); return; }
    setAddrError(warning ?? null);
    setNextUserId(value || null);
  }

  function applyAddress() {
    if (nextUserId) setUserId(nextUserId);
  }

  return (
    <div className="min-h-screen w-full bg-gray-50 flex flex-col items-center justify-center p-6 sm:p-8 md:p-10">
      {/* Header */}
      <div className="mb-6 md:mb-8 text-center">
        <h1 className="text-2xl sm:text-3xl font-bold mb-2 text-gray-800">
          {process.env.NEXT_PUBLIC_SELF_APP_NAME || "Self Workshop"}
        </h1>
        <p className="text-sm sm:text-base text-gray-600 px-2">
          Scan QR code with Self Protocol App to verify your identity
        </p>
      </div>

      {/* Main content */}
      <div className="h-px bg-gray-200 w-full max-w-xl mx-auto mb-4" />
      <div className="bg-white rounded-xl shadow-lg p-6 w-full max-w-xl mx-auto mt-2 text-center">
        {/* Connect wallet */}
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-1 text-center">Connected Address</label>
          <div className="mt-1 text-xs font-mono text-gray-700 break-all">{walletAddress || "Not connected"}</div>
          <div className="mt-3 flex gap-2 justify-center">
            <button type="button" onClick={connectWallet} className="px-3 py-2 rounded-md bg-blue-600 text-white text-sm">Connect Wallet</button>
            {walletError && <span className="text-xs text-amber-600 self-center">{walletError}</span>}
          </div>
        </div>

        <div className="flex justify-center mb-4 sm:mb-6">
          {selfApp ? (
            <SelfQRcodeWrapper
              selfApp={selfApp}
              onSuccess={handleSuccessfulVerification}
              onError={() => {
                displayToast("Error: Failed to verify identity");
              }}
            />
          ) : (
            <div className="w-[256px] h-[256px] bg-gray-200 animate-pulse flex items-center justify-center">
              <p className="text-gray-500 text-sm">Loading QR Code...</p>
            </div>
          )}
        </div>
        {/* Status moved to /status */}

        {isMobile && (
          <div className="flex flex-col sm:flex-row gap-2 sm:space-x-2 mb-4 sm:mb-6 justify-center items-center">
            <button
              type="button"
              onClick={copyToClipboard}
              disabled={!universalLink}
              className="flex-1 bg-gray-800 hover:bg-gray-700 transition-colors text-white p-2 rounded-md text-sm sm:text-base disabled:bg-gray-400 disabled:cursor-not-allowed"
            >
              {linkCopied ? "Copied!" : "Copy Universal Link"}
            </button>

            <button
              type="button"
              onClick={openSelfApp}
              disabled={!universalLink}
              className="flex-1 bg-blue-600 hover:bg-blue-500 transition-colors text-white p-2 rounded-md text-sm sm:text-base mt-2 sm:mt-0 disabled:bg-blue-300 disabled:cursor-not-allowed"
            >
              Open Self App
            </button>
          </div>
        )}
        <div className="flex flex-col items-center gap-2 mt-2 text-center">
          <span className="text-gray-500 text-xs uppercase tracking-wide">Connected Address</span>
          <div className="bg-gray-100 rounded-md px-3 py-2 w-full text-center break-all text-sm font-mono text-gray-800 border border-gray-200">
            {walletAddress || <span className="text-gray-400">Not connected</span>}
          </div>
        </div>

        {/* Toast notification */}
        {showToast && (
          <div className="fixed bottom-4 right-4 bg-gray-800 text-white py-2 px-4 rounded shadow-lg animate-fade-in text-sm">
            {toastMessage}
          </div>
        )}
      </div>
    </div>
  );
}
