"use client";

import React, { useEffect, useMemo, useState } from "react";
import { useSearchParams, useRouter } from "next/navigation";

type SourceEvent = { txHash: string; blockNumber: number; user: string; dstEid: number; configId: string };
type DestEvent = { txHash: string; blockNumber: number; user: string; srcEid: number; timestamp: number };

export default function StatusPage() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const userFilter = (searchParams.get("user") || "").toLowerCase();
  const [src, setSrc] = useState<SourceEvent[]>([]);
  const [dst, setDst] = useState<DestEvent[]>([]);
  const [warnings, setWarnings] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  const filteredSrc = useMemo(() => (
    userFilter ? src.filter(e => e.user.toLowerCase() === userFilter) : src
  ), [src, userFilter]);
  const filteredDst = useMemo(() => (
    userFilter ? dst.filter(e => e.user.toLowerCase() === userFilter) : dst
  ), [dst, userFilter]);

  useEffect(() => {
    let timer: NodeJS.Timeout;
    const run = async () => {
      try {
        setLoading(true);
        const res = await fetch("/api/status");
        const data = await res.json();
        setSrc(data.src ?? []);
        setDst(data.dst ?? []);
        setWarnings(data.warnings ?? []);
      } catch (e) {
        setWarnings(["Failed to fetch status"]);
      } finally {
        setLoading(false);
      }
    };
    run();

    // Smart polling: stop if both src and dst have transactions for the current user
    const shouldContinuePolling = () => {
      if (userFilter) {
        const hasUserSrc = src.some(e => e.user.toLowerCase() === userFilter);
        const hasUserDst = dst.some(e => e.user.toLowerCase() === userFilter);
        return !(hasUserSrc && hasUserDst);
      }
      // For general view, stop if we have any transactions
      return src.length === 0 && dst.length === 0;
    };

    if (shouldContinuePolling()) {
      timer = setInterval(run, 5000);
    }

    return () => clearInterval(timer);
  }, [src, dst, userFilter]);

  const hasUserTransactions = userFilter ?
    (filteredSrc.length > 0 && filteredDst.length > 0) :
    (src.length > 0 && dst.length > 0);

  const isPolling = !hasUserTransactions;

  return (
    <div className="min-h-screen w-full bg-gradient-to-br from-blue-50 to-indigo-100 p-4 sm:p-6 md:p-8">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Cross-chain Verification Status</h1>
          <p className="text-gray-600">Track your identity verification messages across Celo and Base</p>
        </div>

        {/* Controls */}
        <div className="flex flex-wrap justify-center gap-3 mb-6">
          <button
            onClick={() => router.push("/")}
            className="px-4 py-2 rounded-lg bg-white border border-gray-300 hover:bg-gray-50 text-gray-700 transition-colors"
          >
            ← Back to QR
          </button>
          <button
            onClick={() => location.reload()}
            className="px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white transition-colors"
          >
            🔄 Refresh
          </button>
          {isPolling && (
            <div className="px-4 py-2 rounded-lg bg-green-100 border border-green-300 text-green-700 flex items-center gap-2">
              <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
              Auto-updating every 5s
            </div>
          )}
          {!isPolling && hasUserTransactions && (
            <div className="px-4 py-2 rounded-lg bg-emerald-100 border border-emerald-300 text-emerald-700 flex items-center gap-2">
              <div className="w-2 h-2 bg-emerald-500 rounded-full"></div>
              Complete - Auto-update stopped
            </div>
          )}
        </div>

        {/* User Filter */}
        {userFilter && (
          <div className="mb-6 text-center">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-blue-100 border border-blue-200 rounded-lg text-blue-800">
              <span className="text-sm font-medium">Filtering by user:</span>
              <span className="font-mono text-sm">{userFilter}</span>
              <button
                onClick={() => router.push("/status")}
                className="ml-2 text-blue-600 hover:text-blue-800 text-sm"
              >
                ✕ Clear filter
              </button>
            </div>
          </div>
        )}

        {/* Warnings */}
        {warnings.length > 0 && (
          <div className="mb-6">
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
              <h3 className="text-sm font-medium text-amber-800 mb-2">⚠️ System Notifications</h3>
              {warnings.map((w, i) => (
                <div key={i} className="text-sm text-amber-700">{w}</div>
              ))}
            </div>
          </div>
        )}

        {/* Transaction Status Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Source Chain */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
            <div className="bg-gradient-to-r from-green-500 to-emerald-600 p-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-semibold text-white">Celo Mainnet</h2>
                  <p className="text-green-100 text-sm">Source Chain - Verification Sent</p>
                </div>
                <div className="text-right">
                  <div className="text-2xl font-bold text-white">{filteredSrc.length}</div>
                  <div className="text-green-100 text-xs">Recent sends</div>
                </div>
              </div>
            </div>
            <div className="p-4">
              {loading && (
                <div className="flex items-center gap-2 text-gray-500 mb-3">
                  <div className="w-4 h-4 border-2 border-gray-300 border-t-blue-500 rounded-full animate-spin"></div>
                  <span className="text-sm">Loading transactions...</span>
                </div>
              )}
              {filteredSrc.length === 0 && !loading && (
                <div className="text-center py-8 text-gray-500">
                  <div className="text-4xl mb-2">📤</div>
                  <div className="text-sm">No verification sends found</div>
                  {userFilter && <div className="text-xs mt-1">for user {userFilter}</div>}
                </div>
              )}
              {filteredSrc.map((e, i) => (
                <div key={`src-${i}`} className="border-b border-gray-100 pb-3 mb-3 last:border-b-0 last:mb-0">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium text-gray-900 mb-1">
                        User: <span className="font-mono text-xs">{e.user}</span>
                      </div>
                      <div className="text-xs text-gray-600 mb-2">
                        Block #{e.blockNumber} • Destination EID: {e.dstEid}
                      </div>
                      <a
                        className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800 bg-blue-50 hover:bg-blue-100 px-2 py-1 rounded transition-colors"
                        href={`${process.env.NEXT_PUBLIC_SOURCE_EXPLORER}/tx/${e.txHash}`}
                        target="_blank"
                        rel="noreferrer"
                      >
                        <span>View on Celoscan</span>
                        <span>↗</span>
                      </a>
                    </div>
                    <div className="text-green-500 text-lg">✓</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Destination Chain */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
            <div className="bg-gradient-to-r from-blue-500 to-indigo-600 p-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-semibold text-white">Base Mainnet</h2>
                  <p className="text-blue-100 text-sm">Destination Chain - Verification Received</p>
                </div>
                <div className="text-right">
                  <div className="text-2xl font-bold text-white">{filteredDst.length}</div>
                  <div className="text-blue-100 text-xs">Recent receipts</div>
                </div>
              </div>
            </div>
            <div className="p-4">
              {loading && (
                <div className="flex items-center gap-2 text-gray-500 mb-3">
                  <div className="w-4 h-4 border-2 border-gray-300 border-t-blue-500 rounded-full animate-spin"></div>
                  <span className="text-sm">Loading transactions...</span>
                </div>
              )}
              {filteredDst.length === 0 && !loading && (
                <div className="text-center py-8 text-gray-500">
                  <div className="text-4xl mb-2">📥</div>
                  <div className="text-sm">No verification receipts found</div>
                  {userFilter && <div className="text-xs mt-1">for user {userFilter}</div>}
                </div>
              )}
              {filteredDst.map((e, i) => (
                <div key={`dst-${i}`} className="border-b border-gray-100 pb-3 mb-3 last:border-b-0 last:mb-0">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium text-gray-900 mb-1">
                        User: <span className="font-mono text-xs">{e.user}</span>
                      </div>
                      <div className="text-xs text-gray-600 mb-2">
                        Block #{e.blockNumber} • Source EID: {e.srcEid}
                      </div>
                      <a
                        className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800 bg-blue-50 hover:bg-blue-100 px-2 py-1 rounded transition-colors"
                        href={`${process.env.NEXT_PUBLIC_DEST_EXPLORER}/tx/${e.txHash}`}
                        target="_blank"
                        rel="noreferrer"
                      >
                        <span>View on Basescan</span>
                        <span>↗</span>
                      </a>
                    </div>
                    <div className="text-blue-500 text-lg">✓</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Success Message */}
        {hasUserTransactions && (
          <div className="mt-8 text-center">
            <div className="inline-flex items-center gap-3 bg-emerald-50 border border-emerald-200 rounded-lg px-6 py-4">
              <div className="text-emerald-500 text-2xl">🎉</div>
              <div>
                <div className="text-emerald-800 font-semibold">Cross-chain verification complete!</div>
                <div className="text-emerald-600 text-sm">
                  {userFilter ?
                    `Identity verification for ${userFilter} has been successfully sent and received.` :
                    "Identity verifications have been successfully processed across chains."
                  }
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
