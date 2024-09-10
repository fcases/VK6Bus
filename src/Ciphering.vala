using Posix;
using GCrypt.Cipher;

namespace ProtocolBus {

    public class Ciphering {
        private Cipher cipher;
        uchar[] blackbytes;
        uchar[] redbytes;

        public Ciphering(uchar[] key, uchar[] iv) {
            GCrypt.Error err = Cipher.open(out cipher, Algorithm.AES256, Mode.CBC, Flag.SECURE);
            cipher.set_key(key);
            cipher.set_iv(iv);
            blackbytes=new uchar[64000];
            redbytes=new uchar[64000];
        }

        ~Ciphering() {
            cipher.close();
        }
                    
        public Bytes Encrypt(Bytes RedBytes) {
            Bytes aux;

            lock(cipher){
                var out_length=(RedBytes.length / 16 + 1) * 16;
                memcpy(redbytes,RedBytes.get_data(),RedBytes.length);
                memset((uchar *)&redbytes[RedBytes.length],0,out_length-RedBytes.length);
                //  for(var i = RedBytes.length; i < pad_length; i++) RedBytes.data[i] = '@';

                GCrypt.Error e=cipher.encrypt(blackbytes,RedBytes.get_data());
                aux=new Bytes.take(blackbytes[0:out_length-1]);
            }

            return aux;
        }

        public Bytes Decrypt(Bytes BlackBytes) {
            Bytes aux;
            lock(cipher){
                var len = (BlackBytes.length / 16 + 1) * 16;

                GCrypt.Error e=cipher.decrypt(redbytes,BlackBytes.get_data());
                aux=new Bytes.take(redbytes[0:len-1]);
            }
            return aux;
        }

        public static ulong GetHash64(string text) {
            ulong hash = 0;
            int size = text.length;

            switch (size) {
            case 0:
                hash = 0;
                break;
            case 1:
                hash = (ulong)(text.hash() & 0x00000000FFFFFFFF);
                break;
            default:
                string s1 = text.substring(0, text.length / 2);
                string s2 = text.substring(text.length / 2);
                var _ms4b =GetFNV1aHashCode(s1);
                uint8 *ms4b=(uint8*)&_ms4b;
                var _ls4b = GetFNV1aHashCode(s2);
                uint8 *ls4b=(uint8*)&_ls4b;
                hash = (ulong)ms4b[0] << 56 | (ulong)ms4b[1] << 48 |
                        (ulong)ms4b[2] << 40 | (ulong)ms4b[3] << 32 |
                        (ulong)ls4b[0] << 24 | (ulong)ls4b[1] << 16 |
                        (ulong)ls4b[2] << 8  | (ulong)ls4b[3];
                break;
            }

            return hash;
        }

        private static uint32 GetFNV1aHashCode(string str) {
            if (str == null)
                return 0;

            var length = str.length;
            uint32 hash = (uint32)2166136261;

            for (int i = 0; i < length; i++) {
                hash = (hash ^ str[i]) * 16777619;
            }
            return hash;
        }
    }
}


