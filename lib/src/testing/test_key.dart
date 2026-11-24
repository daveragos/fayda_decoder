// A throwaway RSA key for signing synthetic test payloads.
//
// It is published with the package, so anyone can sign with it. Never trust
// it outside tests. Regenerate with:
//   openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048

/// PEM public key matching the test signing key.
const testPublicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqRNtJXt64S5EQUeF+7Xj
rpAfOaqlo7pCVY9m+sHyYvYz5VnI+a1dJwroHfDy1PqluRO7NLi2rloPnKUAvaP6
DA4fRQyNfoCCVzjI83+HPLsERSn/WWeIxWE+vHlHHn39Eg9LJ9rYU0tOpBaF3z/O
8Y4CBOz1wjQGUuBhfwVrXMp1wOtHuwZ52t56+8AKl7ed8VICpALmBPdk1ujavu9i
6Kwb19aT5VstRhI/b+zbOMCGWfpNsOVkwTSo+Og5tgK5b/HNziv9UMrmmNzP/Iyr
MxuQ3HMcs33zQBZs4o/AyvgbIxc1Uyy7x+/eSFm3V+jxZ0TE9Kv0KsGF/Bu3DR3L
BQIDAQAB
-----END PUBLIC KEY-----''';

const _modulus =
    'a9136d257b7ae12e44414785fbb5e3ae901f39aaa5a3ba42558f66fac1f262f6'
    '33e559c8f9ad5d270ae81df0f2d4faa5b913bb34b8b6ae5a0f9ca500bda3fa0c'
    '0e1f450c8d7e80825738c8f37f873cbb044529ff596788c5613ebc79471e7dfd'
    '120f4b27dad8534b4ea41685df3fcef18e0204ecf5c2340652e0617f056b5cca'
    '75c0eb47bb0679dade7afbc00a97b79df15202a402e604f764d6e8dabeef62e8'
    'ac1bd7d693e55b2d46123f6fecdb38c08659fa4db0e564c134a8f8e839b602b9'
    '6ff1cdce2bfd50cae698dccffc8cab331b90dc731cb37df340166ce28fc0caf8'
    '1b231735532cbbc7efde4859b757e8f16744c4f4abf42ac185fc1bb70d1dcb05';

const _p = 'ebd8085eea0debdda03503f3cf5968e4a25437d2da1ed07dbdc02f6777a0df66'
    '2efad29d7e5de3d1c1c382d528e1b5b4acafdd8798c7ffed4faecccdf091015c'
    '9f1d59669800a4e7fe67df0debfc8e6ed3a342020fb0e9ebf0ddccfb31a11b7b'
    '73c424ccdd070e387f6ff5a4b2caa89f42993617cf8929c4a8672d020c8beb77';

const _q = 'b786980e178e67b5837c1201e57161106106d2bdca60aa611eaef473ad460ee8'
    '8083f5190b5235339111b5ce11c0ef708b47ccb050dfe7a3322b320d1d6e5a64'
    '68ecc928b266109d90b9d2dcca5305996cca6e856731d32a23824d79ece3233a'
    '23260c212eace34154907494ca5870d19c955274dc0bba2b5a883e9b38832463';

const _dp = '784e585eca785584559015b70e63a69d52ad3158cec97f4355432f2b519befb9'
    'b9675b7ed9925d7f879f0b235f5a5c0d91359904ed8bc062b70e0d0d549533a3'
    'a2cb1eeab5c94655cdb200d7a234d0177ac04210b91e5f056b7649752de8e812'
    'fe87e4d9d83a1c27f7e20de5790ae61f6fa2a634593ab7e2c8a0f115a57ece9b';

const _dq = 'b3f994f1f4dddd0c5f15f3ded22ffebcfe399fbf2950e4a4fb5f1d30b792c599'
    'f235f5cd0a9222c420169b10abce65c11b855cd0e76ebc0d096cdcd789ae278c'
    'e26c9ad483269e52b693d49a5afb51b964bb9be8cd0b4a86bf6dd026aa4d10c5'
    'b9a45d2ec94418547fe66dbd60359ce5a245b9280a86a19a545cd9f08459eefb';

const _qInv = '4d113341ea566291368d73f53cf13581c4ac0317599bf796eab601b072eead6f'
    '2b55c91bb0a01aee8fd6776953012090c53966a8c170bdf8951d0ce03bc71df5'
    '887cb1b35e89b7e12f4d328f4719981786b0e000e8cbd3710bdb9048b6ea7ba2'
    'caac783c62fa7392f4f7faba60f8915da6cbbfaf36b82189c1c847d1bec45054';

/// Hex components of the test key, in CRT form.
const testKeyHex = (
  modulus: _modulus,
  p: _p,
  q: _q,
  dp: _dp,
  dq: _dq,
  qInv: _qInv,
);
