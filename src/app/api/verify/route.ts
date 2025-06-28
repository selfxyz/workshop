import { NextRequest, NextResponse } from "next/server";
import { countries, Country3LetterCode, SelfAppDisclosureConfig } from "@selfxyz/common";
import {
  countryCodes,
  SelfBackendVerifier,
  AllIds,
  DefaultConfigStore,
  VerificationConfig
} from "@selfxyz/core";

export async function POST(req: NextRequest) {
  console.log("Received request");
  console.log(req);
  try {
    const { attestationId, proof, publicSignals, userContextData } = await req.json();

    if (!proof || !publicSignals || !attestationId || !userContextData) {
      return NextResponse.json({
        message:
          "Proof, publicSignals, attestationId and userContextData are required",
      }, { status: 400 });
    }

    const disclosures_config: VerificationConfig = {
      excludedCountries: [
        countries.NORTH_KOREA,
      ] as Country3LetterCode[],
      ofac: false,
      minimumAge: 15,
    };

    const configStore = new DefaultConfigStore(disclosures_config);

    const selfBackendVerifier = new SelfBackendVerifier(
      "self-workshop",
      process.env.NEXT_PUBLIC_SELF_ENDPOINT || "",
      true,
      AllIds,
      configStore,
      "hex",
    );

    const result = await selfBackendVerifier.verify(
      attestationId,
      proof,
      publicSignals,
      userContextData
    );
    if (!result.isValidDetails.isValid) {
      return NextResponse.json({
        status: "error",
        result: false,
        message: "Verification failed",
        details: result.isValidDetails,
      }, { status: 500 });
    }

    const saveOptions = (await configStore.getConfig(
      result.userData.userIdentifier
    )) as unknown as SelfAppDisclosureConfig;

    if (result.isValidDetails.isValid) {
      const filteredSubject = { ...result.discloseOutput };

      if (!saveOptions.issuing_state && filteredSubject) {
        filteredSubject.issuingState = "Not disclosed";
      }
      if (!saveOptions.name && filteredSubject) {
        filteredSubject.name = "Not disclosed";
      }
      if (!saveOptions.nationality && filteredSubject) {
        filteredSubject.nationality = "Not disclosed";
      }
      if (!saveOptions.date_of_birth && filteredSubject) {
        filteredSubject.dateOfBirth = "Not disclosed";
      }
      if (!saveOptions.passport_number && filteredSubject) {
        filteredSubject.idNumber = "Not disclosed";
      }
      if (!saveOptions.gender && filteredSubject) {
        filteredSubject.gender = "Not disclosed";
      }
      if (!saveOptions.expiry_date && filteredSubject) {
        filteredSubject.expiryDate = "Not disclosed";
      }

      console.log(filteredSubject);

      return NextResponse.json({
        status: "success",
        result: result.isValidDetails.isValid,
        credentialSubject: filteredSubject,
        verificationOptions: {
          minimumAge: saveOptions.minimumAge,
          ofac: saveOptions.ofac,
          excludedCountries: saveOptions.excludedCountries?.map(
            (countryName) => {
              const entry = Object.entries(countryCodes).find(
                ([_, name]) => name === countryName
              );
              return entry ? entry[0] : countryName;
            }
          ),
        },
      });
    } else {
      return NextResponse.json({
        status: "error",
        result: result.isValidDetails.isValid,
        message: "Verification failed",
        details: result,
      }, { status: 400 });
    }
  } catch (error) {
    console.error("Error verifying proof:", error);
    return NextResponse.json({
      status: "error",
      result: false,
      message: error instanceof Error ? error.message : "Unknown error",
    }, { status: 500 });
  }
}