B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.3
@EndOfDesignText@
Sub Class_Globals
	Type W3Credentials (PrivateKey() As Byte, PublicKey As BigInteger, Address As String, Native As JavaObject)
	Type W3Error (Code As Int, Message As String, Data As String)
	Type W3AsyncResult (Success As Boolean, Value As Object, Error As W3Error)
	Private jme As JavaObject
	Public BLOCK_EARLIEST, BLOCK_LATEST, BLOCK_PENDING As Object
	Private Units As Map
	Private SignClass As JavaObject
	Private NumericClass As JavaObject
	Private HashClass As JavaObject
	Private KeysClass As JavaObject
	Public Const CHAINID_MAINNET = 1, CHAINID_ROPSTEN = 3, CHAINID_RINKEBY = 4, CHAINID_GOERLI = 5, CHAINID_KOTTI = 6 As Int
End Sub

Public Sub Initialize
	jme = Me
	Dim jo As JavaObject
	jo.InitializeStatic("org.web3j.protocol.core.DefaultBlockParameterName")
	BLOCK_EARLIEST = jo.GetField("EARLIEST")
	BLOCK_LATEST = jo.GetField("LATEST")
	BLOCK_PENDING = jo.GetField("PENDING")
	jo.InitializeStatic("org.web3j.utils.Convert.Unit")
	Units.Initialize
	Units.Put("wei", jo.GetField("WEI"))
	Units.Put("kwei", jo.GetField("KWEI"))
	Units.Put("mwei", jo.GetField("MWEI"))
	Units.Put("gwei", jo.GetField("GWEI"))
	Units.Put("szabo", jo.GetField("SZABO"))
	Units.Put("finney", jo.GetField("FINNEY"))
	Units.Put("ether", jo.GetField("ETHER"))
	SignClass.InitializeStatic("org.web3j.crypto.Sign")
	NumericClass.InitializeStatic("org.web3j.utils.Numeric")
	HashClass.InitializeStatic("org.web3j.crypto.Hash")
	KeysClass.InitializeStatic("org.web3j.crypto.Keys")
End Sub

'Creates a Web3 object which uses Infura as its provider.
Public Sub BuildWeb3Infura (Link As String) As Web3X
	Dim jo As JavaObject
	jo.InitializeNewInstance("org.web3j.protocol.infura.InfuraHttpService", Array(Link))
	Return CreateWeb3X(jo)
End Sub

Public Sub BuildWeb3Http (Link As String) As Web3X
	Dim jo As JavaObject
	jo.InitializeNewInstance("org.web3j.protocol.http.HttpService", Array(Link))
	Return CreateWeb3X(jo)
End Sub

Private Sub CreateWeb3X (jo As Object) As Web3X
	Dim w As Web3X
	w.Initialize(jo, Me)
	Return w
End Sub

'Converts a hex string to BigInteger.
Public Sub BigIntFromHex (Hex As String) As BigInteger
	Dim jo As JavaObject
	jo.InitializeNewInstance("java.math.BigInteger", Array(CleanHexPrefix(Hex), 16))
	Return BigIntFromNative(jo)
End Sub

'Converts a BigInteger to hex string.
Public Sub BigIntToHex (Bi As BigInteger) As String
	Return Bi.ToStringBase(16)
End Sub

'Converts an array of bytes, previously exported from a BigInteger, to BigInteger.
Public Sub BigIntFromBytes (Key() As Byte) As BigInteger
	Dim Bi As BigInteger
	Bi.Initialize2(Key)
	Return Bi
End Sub

'Convert BigDecimal to native API.
Public Sub BigDecToNative(bd As BigDecimal) As Object
	If bd = Null Then Return Null
	Return bd.As(JavaObject).GetField("bigd")
End Sub
'Converts from native API to BigDecimal.
Public Sub BigDecFromNative(Native As Object) As BigDecimal
	Dim bd As BigDecimal
	bd.As(JavaObject).SetField("bigd", Native)
	Return bd
End Sub
'Converts from native API to BigInteger.
Public Sub BigIntFromNative(Native As JavaObject) As BigInteger
	if Native = Null or Native.IsInitialized = False Then Return Null
	Dim Bi As BigInteger
	Bi.As(JavaObject).SetField("bigi", Native)
	Return Bi
End Sub
'Converts BigInteger to native API.
Public Sub BigIntToNative(Bi As BigInteger) As Object
	If Bi = Null Then Return Null
	Return Bi.As(JavaObject).GetField("bigi")
End Sub

'Returns a new string without the '0x' prefix. Returns the same string if no prefix.
Public Sub CleanHexPrefix(Hex As String) As String
	If Hex.StartsWith("0x") Then Return Hex.SubString(2)
	Return Hex
End Sub

'Create credentials based on private key.
Public Sub CreateCredentialsFromPrivateKey (Key() As Byte) As W3Credentials
	Dim credentials As JavaObject
	credentials = credentials.InitializeStatic("org.web3j.crypto.Credentials").RunMethod("create", Array(BigIntFromBytes(Key).ToStringBase(16)))
	Return CreateCredentials(credentials)
End Sub

'Creates a BigInteger with value measured in wei. FromUnit can be one of: wei, kwei, mwei, gwei, szabo, finner and ether.
Public Sub BigIntFromUnit (Number As String, FromUnit As String) As BigInteger
	Return BigDecFromUnit(Number, FromUnit).ToBigInteger
End Sub

'Creates a BigInteger from a Long typed number.
Public Sub BigIntFromNumber (Number As Long) As BigInteger
	Dim bi As BigInteger
	bi.Initialize3(Number)
	Return bi
End Sub

'Creates a BigDecimal with value measured in wei. FromUnit can be one of: wei, kwei, mwei, gwei, szabo, finner and ether.
Public Sub BigDecFromUnit (Number As String, FromUnit As String) As BigDecimal
	Dim Convert As JavaObject
	Convert.InitializeStatic("org.web3j.utils.Convert")
	Return BigDecFromNative(Convert.RunMethod("toWei", Array(Number, GetNativeUnit(FromUnit))))
End Sub

'Converts a BigInteger to BigDecimal.
Public Sub BigDecFromBigInt(BigInt As BigInteger) As BigDecimal
	Dim bd As JavaObject
	bd.InitializeNewInstance("java.math.BigDecimal", Array(BigIntToNative(BigInt)))
	Return BigDecFromNative(bd)
End Sub

' (internal) Returns the native unit object.
Public Sub GetNativeUnit(UnitName As String) As Object
	Return Units.Get(UnitName.ToLowerCase)
End Sub

'Converts a value measured in wei to a different unit. ToUnit can be one of: wei, kwei, mwei, gwei, szabo, finner and ether.
Public Sub ConvertFromWei (Number As String, ToUnit As String) As BigDecimal
	Dim Convert As JavaObject
	Convert.InitializeStatic("org.web3j.utils.Convert")
	Return BigDecFromNative(Convert.RunMethod("fromWei", Array(Number, GetNativeUnit(ToUnit))))
End Sub

Private Sub CreateCredentials(Native As JavaObject) As W3Credentials
	Dim c As W3Credentials
	c.Initialize
	c.Native = Native
	c.PrivateKey = Native.RunMethodJO("getEcKeyPair", Null).RunMethodJO("getPrivateKey", Null).RunMethod("toByteArray", Null)
	c.PublicKey = BigIntFromNative(Native.RunMethodJO("getEcKeyPair", Null).RunMethod("getPublicKey", Null))
	c.Address = Native.RunMethod("getAddress", Null)
	Return c
End Sub

'Asynchronously creates a new wallet file with random keys. Result.Value holds the full path to the wallet file.
'Light - Weaker and faster encryption algorithm will be used to encrypt the wallet data.
Public Sub GenerateNewWallet (Dir As String, Password As String, Light As Boolean) As ResumableSub
	Dim wu As JavaObject
	wu.InitializeStatic("org.web3j.crypto.WalletUtils")
	Dim sf As Object = RunAsync(wu, "generateNewWalletFile", Array(Password, _
		DirFileToFile(Dir, ""), Not(Light)))
	Wait For (sf) RunAsync_Complete (Success As Boolean, Path As Object, Error As W3Error)
	Return CreateW3AsyncResult(Success, Path, Error)
End Sub

'Asynchronously creates a new wallet file based on the provided private key. Result.Value holds the full path to the wallet file.
'Light - Weaker and faster encryption algorithm will be used to encrypt the wallet data.
Public Sub GenerateWalletWithPrivateKey (Dir As String, Password As String, PrivateKey() As Byte, Light As Boolean) As ResumableSub
	Dim c As W3Credentials = CreateCredentialsFromPrivateKey(PrivateKey)
	Dim wu As JavaObject
	wu.InitializeStatic("org.web3j.crypto.WalletUtils")
	Dim sf As Object = RunAsync(wu, "generateWalletFile", Array(Password, c.Native.RunMethod("getEcKeyPair", Null), _
		DirFileToFile(Dir, ""), Not(Light)))
	Wait For (sf) RunAsync_Complete (Success As Boolean, Path As Object, Error As W3Error)
	Return CreateW3AsyncResult(Success, Path, Error)
End Sub

'Asynchronously loads an existing layout. Result.Value type is W3Credentials.
Public Sub LoadWallet (Path As String, Password As String) As ResumableSub
	Dim wu As JavaObject
	wu.InitializeStatic("org.web3j.crypto.WalletUtils")
	Dim sf As Object = RunAsync(wu, "loadCredentials", Array(Password, Path))
	Wait For (sf) RunAsync_Complete (Success As Boolean, Credentials As Object, Error As W3Error)
	Return CreateW3AsyncResult(Success, IIf(Success, CreateCredentials(Credentials), Null), Error)
End Sub

'Signs a message. Returns the signature bytes. Signature algorithm is explained <link>here|https://web3js.readthedocs.io/en/v1.5.2/web3-eth-personal.html#sign</link>.
Public Sub SignPrefixedMessage (Message() As Byte, Credentials As W3Credentials) As Byte()
	Dim SignatureData As JavaObject = SignClass.RunMethod("signPrefixedMessage", Array(Message, Credentials.Native.RunMethod("getEcKeyPair", Null)))
	Dim bb As B4XBytesBuilder
	bb.Initialize
	bb.Append(SignatureData.RunMethod("getR", Null))
	bb.Append(SignatureData.RunMethod("getS", Null))
	bb.Append(SignatureData.RunMethod("getV", Null))
	Return bb.ToArray
End Sub

'Tests whether the message was signed with the given address.
Public Sub VerifySignature(Message() As Byte, Signature() As Byte, Address As String) As Boolean
	Dim keys As List = ExtractPublicKeysFromSignature(Message, Signature)
	Dim res As List
	res.Initialize
	Dim Target As String = CleanHexPrefix(Address).ToLowerCase
	For Each b As BigInteger In keys
		Dim add As String = KeysClass.RunMethod("getAddress", Array(b.ToStringBase(16)))
		If add.ToLowerCase = Target Then Return True
	Next
	Return False
End Sub

'Extracts the address from the public key.
Public Sub GetAddressFromPublicKey (PublicKey As BigInteger) As String
	Return ConvertAddressToChecksumAddress(KeysClass.RunMethod("getAddress", Array(PublicKey.ToStringBase(16))))
End Sub

'Returns a list with the possible public keys (BigInteger) of the credentials used to sign. The list size will be between 0 to 2.
Public Sub ExtractPublicKeysFromSignature(Message() As Byte, Signature() As Byte) As List
	Dim res As List
	res.Initialize
	Dim r(32), s(32) As Byte
	Bit.ArrayCopy(Signature, 0, r, 0, 32)
	Bit.ArrayCopy(Signature, 32, s, 0, 32)
	Dim v As Byte = Signature(64)
	Dim SignatureData As JavaObject
	SignatureData.InitializeNewInstance("org.web3j.crypto.Sign.SignatureData", Array(v, r, s))
	Dim ECDSASignature As JavaObject
	ECDSASignature.InitializeNewInstance("org.web3j.crypto.ECDSASignature", Array(BigIntToNative(BigIntFromBytes(r)), BigIntToNative(BigIntFromBytes(s))))
	Dim hash() As Byte = SignClass.RunMethod("getEthereumMessageHash", Array(Message))
	For i = 0 To 3
		Dim publickey As JavaObject = SignClass.RunMethod("recoverFromSignature", Array(i, ECDSASignature, hash))
		If publickey.IsInitialized Then
			res.Add(BigIntFromNative(publickey))
		End If
	Next
	Return res
End Sub

'Converts an address with any case to checksum case.
Public Sub ConvertAddressToChecksumAddress (Address As String) As String
	Return KeysClass.RunMethod("toChecksumAddress", Array(Address))
End Sub

Private Sub DirFileToFile(Dir As String, FileName As String) As Object
	Dim jo As JavaObject
	jo.InitializeNewInstance("java.io.File", Array(File.Combine(Dir, FileName)))
	Return jo
End Sub

Private Sub RunAsync(Target As Object, Method As String, Params() As Object) As Object
	Return jme.RunMethod("runAsync", Array(Me, Target, Method, Params))
End Sub

'internal
Public Sub CreateW3AsyncResult (Success As Boolean, Result As Object, Error As W3Error) As W3AsyncResult
	Dim t1 As W3AsyncResult
	t1.Initialize
	t1.Success = Success
	t1.Value = Result
	If Success = False Then
		t1.Error = Error
	End If
	Return t1
End Sub

#if java
import anywheresoftware.b4j.object.JavaObject;
import java.util.concurrent.Callable;
import java.util.ArrayList;
import java.util.List;
public Object runAsync(final B4AClass instance, final Object target, final String method, final Object[] params) {
	Object sender = new Object();
	BA.runAsync(instance.getBA(), sender, "runasync_complete", null, 
		new Callable<Object[]>() {
			public Object[] call() throws Exception {
				JavaObject jo = new JavaObject();
				jo.setObject(target);
				try {
					return new Object[] {true, jo.RunMethod(method, params), null};
				} catch (Exception e) {
					return new Object[] {false, null, w3errorFromException(e)};
				}
			}
		}
	);
	return sender;
}
public static _w3error w3errorFromException(Exception e) {
	_w3error ee = new _w3error();
	ee.IsInitialized = true;
	ee.Code = -1;
	ee.Data = "";
	ee.Message = e.getMessage();
	return ee;
}
#end if

Public Sub CreateW3Error (Code As Int, Message As String, Data As String) As W3Error
	Dim t1 As W3Error
	t1.Initialize
	t1.Code = Code
	t1.Message = Message
	t1.Data = Data
	Return t1
End Sub