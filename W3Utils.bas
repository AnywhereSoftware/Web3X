﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.3
@EndOfDesignText@
Sub Class_Globals
	Type W3Credentials (PrivateKey() As Byte, PublicKey As BigInteger, Address As String, Native As JavaObject)
	Type W3AsyncResult (Success As Boolean, Value As Object, Error As Exception)
	Private jme As JavaObject
	Public BLOCK_EARLIEST, BLOCK_LATEST, BLOCK_PENDING As Object
	Private Units As Map
	Private SignClass As JavaObject
	Private NumericClass As JavaObject
	Private HashClass As JavaObject
	Private KeysClass As JavaObject
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

Public Sub BuildWeb3Infura (Link As String) As Web3X
	Dim jo As JavaObject
	jo.InitializeNewInstance("org.web3j.protocol.infura.InfuraHttpService", Array(Link))
	Dim w As Web3X
	w.Initialize(jo, Me)
	Return w
End Sub

Public Sub BigIntFromHex (Hex As String) As BigInteger
	Dim jo As JavaObject
	jo.InitializeNewInstance("java.math.BigInteger", Array(CleanHexPrefix(Hex), 16))
	Return BigIntFromNative(jo)
End Sub


Public Sub BigIntFromBytes (Key() As Byte) As BigInteger
	Dim Bi As BigInteger
	Bi.Initialize2(Key)
	Return Bi
End Sub

Public Sub BigDecToNative(bd As BigDecimal) As Object
	If bd = Null Then Return Null
	Return bd.As(JavaObject).GetField("bigd")
End Sub

Public Sub BigDecFromNative(Native As Object) As BigDecimal
	Dim bd As BigDecimal
	bd.As(JavaObject).SetField("bigd", Native)
	Return bd
End Sub

Public Sub BigIntFromNative(Native As JavaObject) As BigInteger
	Dim Bi As BigInteger
	Bi.As(JavaObject).SetField("bigi", Native)
	Return Bi
End Sub

Public Sub BigIntToNative(Bi As BigInteger) As Object
	If Bi = Null Then Return Null
	Return Bi.As(JavaObject).GetField("bigi")
End Sub

Public Sub CleanHexPrefix(Hex As String) As String
	If Hex.StartsWith("0x") Then Return Hex.SubString(2)
	Return Hex
End Sub

Public Sub CreateCredentialsFromPrivateKey (Key() As Byte) As W3Credentials
	Dim credentials As JavaObject
	credentials = credentials.InitializeStatic("org.web3j.crypto.Credentials").RunMethod("create", Array(BigIntFromBytes(Key).ToStringBase(16)))
	Return CreateCredentials(credentials)
End Sub

Public Sub BigIntFromUnit (Number As String, FromUnit As String) As BigInteger
	Return BigDecFromUnit(Number, FromUnit).ToBigInteger
End Sub

Public Sub BigDecFromUnit (Number As String, FromUnit As String) As BigDecimal
	Dim Convert As JavaObject
	Convert.InitializeStatic("org.web3j.utils.Convert")
	Return BigDecFromNative(Convert.RunMethod("toWei", Array(Number, GetNativeUnit(FromUnit))))
End Sub

Public Sub BigDecFromBigInt(BigInt As BigInteger) As BigDecimal
	Dim bd As JavaObject
	bd.InitializeNewInstance("java.math.BigDecimal", Array(BigIntToNative(BigInt)))
	Return BigDecFromNative(bd)
End Sub

Public Sub GetNativeUnit(UnitName As String) As Object
	Return Units.Get(UnitName.ToLowerCase)
End Sub

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

Public Sub GenerateNewWallet (Dir As String, Password As String, Light As Boolean) As ResumableSub
	Dim wu As JavaObject
	wu.InitializeStatic("org.web3j.crypto.WalletUtils")
	Dim sf As Object = RunAsync(wu, "generateNewWalletFile", Array(Password, _
		DirFileToFile(Dir, ""), Not(Light)))
	Wait For (sf) RunAsync_Complete (Success As Boolean, Path As Object)
	Return CreateW3AsyncResult(Success, Path, LastException)
End Sub

Public Sub GenerateWalletWithPrivateKey (Dir As String, Password As String, PrivateKey() As Byte, Light As Boolean) As ResumableSub
	Dim c As W3Credentials = CreateCredentialsFromPrivateKey(PrivateKey)
	Dim wu As JavaObject
	wu.InitializeStatic("org.web3j.crypto.WalletUtils")
	Dim sf As Object = RunAsync(wu, "generateWalletFile", Array(Password, c.Native.RunMethod("getEcKeyPair", Null), _
		DirFileToFile(Dir, ""), Not(Light)))
	Wait For (sf) RunAsync_Complete (Success As Boolean, Path As Object)
	Return CreateW3AsyncResult(Success, Path, LastException)
End Sub

Public Sub LoadWallet (Path As String, Password As String) As ResumableSub
	Dim wu As JavaObject
	wu.InitializeStatic("org.web3j.crypto.WalletUtils")
	Dim sf As Object = RunAsync(wu, "loadCredentials", Array(Password, Path))
	Wait For (sf) RunAsync_Complete (Success As Boolean, Credentials As Object)
	Return CreateW3AsyncResult(Success, IIf(Success, CreateCredentials(Credentials), Null), LastException)
End Sub

Public Sub SignPrefixedMessage (Message() As Byte, Credentials As W3Credentials) As Byte()
	Dim SignatureData As JavaObject = SignClass.RunMethod("signPrefixedMessage", Array(Message, Credentials.Native.RunMethod("getEcKeyPair", Null)))
	Dim bb As B4XBytesBuilder
	bb.Initialize
	bb.Append(SignatureData.RunMethod("getR", Null))
	bb.Append(SignatureData.RunMethod("getS", Null))
	bb.Append(SignatureData.RunMethod("getV", Null))
	Return bb.ToArray
End Sub

Public Sub ExtractAddressesFromSignature(Message() As Byte, Signature() As Byte) As List
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
		Dim publickey As Object = SignClass.RunMethod("recoverFromSignature", Array(i, ECDSASignature, hash))
		If publickey <> Null Then
			res.Add(ConvertAddressToChecksumAddress(KeysClass.RunMethod("getAddress", Array(publickey))))
		End If
	Next
	Return res
End Sub

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

Public Sub CreateW3AsyncResult (Success As Boolean, Result As Object, Error As Exception) As W3AsyncResult
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
public Object runAsync(B4AClass instance, final Object target, String method, Object[] params) {
	Object sender = new Object();
	BA.runAsync(instance.getBA(), sender, "runasync_complete", new Object[] {false, null}, 
		new Callable<Object[]>() {
			public Object[] call() throws Exception {
				JavaObject jo = new JavaObject();
				jo.setObject(target);
				return new Object[] {true, jo.RunMethod(method, params)};
			}
		}
	);
	return sender;
}
#end if