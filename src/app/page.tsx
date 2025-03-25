'use client';

import { countries, getUniversalLink } from '@selfxyz/core';
import SelfQRcodeWrapper, { SelfAppBuilder } from '@selfxyz/qrcode';
import { v4 } from 'uuid';

export default function Home() {
  const userId = v4();
  // const address = '0x0006F5B774959120029F3A687b188759914D89a0'

  const selfApp = new SelfAppBuilder({
    appName: "Self Workshop",
    scope: "self-workshop",
    endpoint: `${process.env.NEXT_PUBLIC_SELF_ENDPOINT}/api/verify/`,
    logoBase64: "https://pluspng.com/img-png/images-owls-png-hd-owl-free-download-png-png-image-485.png",
    // userIdType: 'hex',
    userId: userId,
    disclosures: {
      minimumAge: 20,
      ofac: true,
      excludedCountries: [countries.FRANCE],
      name: true,
    }
  }).build();

  console.log('Universal link:', getUniversalLink(selfApp));

  return (
    <div className="h-screen w-full bg-white flex flex-col items-center justify-center gap-4">
      <SelfQRcodeWrapper
        selfApp={selfApp}
        // type='deeplink'
        onSuccess={() => {
          window.location.href = '/verified';
        }}
      />
      <button
        onClick={() => {
          window.alert(getUniversalLink(selfApp));
        }}
        className="mt-4 bg-black text-white p-2 px-3 rounded-md"
      >
        Open Self app
      </button>
    </div>
  );
}
