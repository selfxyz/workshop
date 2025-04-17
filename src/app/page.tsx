"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { countries, getUniversalLink } from "@selfxyz/core";
import SelfQRcodeWrapper, { SelfAppBuilder } from "@selfxyz/qrcode";
import { v4 } from "uuid";

export default function Home() {
  const router = useRouter();
  const [linkCopied, setLinkCopied] = useState(false);
  const [showToast, setShowToast] = useState(false);
  const [toastMessage, setToastMessage] = useState("");

  const userId = v4();

  const minimumAge = 20;
  const excludedCountries = [countries.FRANCE];
  const requireName = true;
  const checkOFAC = true;

  const selfApp = new SelfAppBuilder({
    appName: process.env.NEXT_PUBLIC_SELF_APP_NAME || "Self Workshop",
    scope: process.env.NEXT_PUBLIC_SELF_SCOPE || "self-workshop",
    endpoint: `${process.env.NEXT_PUBLIC_SELF_ENDPOINT}/api/verify/`,
    logoBase64:
      "https://pluspng.com/img-png/images-owls-png-hd-owl-free-download-png-png-image-485.png",
    userId: userId,
    disclosures: {
      minimumAge,
      ofac: checkOFAC,
      excludedCountries,
      name: requireName,
    },
  }).build();

  const universalLink = getUniversalLink(selfApp);

  const displayToast = (message: string) => {
    setToastMessage(message);
    setShowToast(true);
    setTimeout(() => setShowToast(false), 3000);
  };

  const copyToClipboard = () => {
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
    window.open(universalLink, "_blank");
    displayToast("Opening Self App...");
  };

  const handleSuccessfulVerification = () => {
    displayToast("Verification successful! Redirecting...");
    setTimeout(() => {
      router.push("/verified");
    }, 1500);
  };

  return (
    <div className="min-h-screen w-full bg-gray-50 flex flex-col items-center justify-center p-4 sm:p-6 md:p-8">
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
      <div className="bg-white rounded-xl shadow-lg p-4 sm:p-6 w-full max-w-xs sm:max-w-sm md:max-w-md mx-auto">
        <div className="flex justify-center mb-4 sm:mb-6">
          <SelfQRcodeWrapper
            selfApp={selfApp}
            onSuccess={handleSuccessfulVerification}
          />
        </div>

        <div className="flex flex-col sm:flex-row gap-2 sm:space-x-2 mb-4 sm:mb-6">
          <button
            type="button"
            onClick={copyToClipboard}
            className="flex-1 bg-gray-800 hover:bg-gray-700 transition-colors text-white p-2 rounded-md text-sm sm:text-base"
          >
            {linkCopied ? "Copied!" : "Copy Universal Link"}
          </button>

          <button
            type="button"
            onClick={openSelfApp}
            className="flex-1 bg-blue-600 hover:bg-blue-500 transition-colors text-white p-2 rounded-md text-sm sm:text-base mt-2 sm:mt-0"
          >
            Open Self App
          </button>
        </div>

        {/* Configuration Info */}
        <div className="border-t border-gray-200 pt-3 sm:pt-4">
          <h3 className="text-xs sm:text-sm font-medium text-gray-700 mb-2">
            Verification Requirements:
          </h3>
          <ul className="text-xs sm:text-sm text-gray-600 space-y-1">
            <li className="flex items-center">
              <svg
                className="h-3 w-3 sm:h-4 sm:w-4 text-green-500 mr-2"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M5 13l4 4L19 7"
                />
              </svg>
              <span>
                Minimum Age:{" "}
                <span className="font-medium ml-1">{minimumAge}+ years</span>
              </span>
            </li>
            <li className="flex items-center">
              <svg
                className="h-3 w-3 sm:h-4 sm:w-4 text-green-500 mr-2"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M5 13l4 4L19 7"
                />
              </svg>
              <span>
                Name Verification:{" "}
                <span className="font-medium ml-1">
                  {requireName ? "Required" : "Not Required"}
                </span>
              </span>
            </li>
            <li className="flex items-center">
              <svg
                className="h-3 w-3 sm:h-4 sm:w-4 text-green-500 mr-2"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M5 13l4 4L19 7"
                />
              </svg>
              <span>
                OFAC Compliance:{" "}
                <span className="font-medium ml-1">
                  {checkOFAC ? "Enabled" : "Disabled"}
                </span>
              </span>
            </li>
            <li className="flex items-start">
              <svg
                className="h-3 w-3 sm:h-4 sm:w-4 text-red-500 mr-2 mt-0.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
              <span>
                Excluded Countries:{" "}
                <span className="font-medium ml-1">France</span>
              </span>
            </li>
          </ul>
        </div>

        <div className="mt-4 text-xs text-gray-500 text-center">
          User ID: {userId.substring(0, 8)}...
          {userId.substring(userId.length - 4)}
        </div>
      </div>

      {/* Toast notification */}
      {showToast && (
        <div className="fixed bottom-4 right-4 bg-gray-800 text-white py-2 px-4 rounded shadow-lg animate-fade-in text-sm">
          {toastMessage}
        </div>
      )}
    </div>
  );
}
