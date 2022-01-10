﻿B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.3
@EndOfDesignText@
Sub Class_Globals
	Public w3 As JavaObject
	Private mUtils As W3Utils
	Private jMe As JavaObject
	Private EnsResolver As JavaObject
	Type W3TransactionReceipt ( _
		TransactionHash As String, _
		TransactionIndex As BigInteger, _
		BlockHash As String, _
		BlockNumber As BigInteger, _
		CumulativeGasUsed As BigInteger, _
		GasUsed As BigInteger, _
		ContractAddress As String, _
		Root As String, _
		StatusOk As Boolean, _
		FromAddress As String, _
		ToAddress As String, _
		LogsBloom As String, _
		RevertReason As String, _
		EffectiveGasPrice As BigInteger, _
		TransactionType As String, _
		Pending As Boolean, _
		Logs As List _
		)
	Type W3TransactionHash (Hash As String, Nonce As BigInteger)
	Private TransactionManagers As Map
	Private bc As ByteConverter
	Private SendFundsLock As Boolean
	Private PollingDuration As Int = 10000
End Sub

'Don't call!
'Use Web3Utils.Build instead.
Public Sub Initialize (Web3Service As Object, utils As W3Utils)
	Dim s As JavaObject
	w3 = s.InitializeStatic("org.web3j.protocol.Web3j").RunMethod("build", Array(Web3Service))
	mUtils = utils
	jMe = Me
	EnsResolver.InitializeNewInstance("org.web3j.ens.EnsResolver", Array(w3))
	TransactionManagers.Initialize

End Sub

Private Sub GetTransactionManager (Credentials As W3Credentials, ChainId As Long) As Object
	Dim key As String = Credentials.Address & ChainId
	If TransactionManagers.ContainsKey(key) Then Return TransactionManagers.Get(key)
	Dim joBA As JavaObject
	joBA.InitializeStatic("anywheresoftware.b4a.BA")
	Dim package As String = joBA.GetField("packageName")
	Dim TransactionManager As JavaObject
	TransactionManager.InitializeNewInstance(package & ".web3x$MyTransactionManager" , Array(w3, Credentials.Native))
	TransactionManagers.Put(key, TransactionManager)
	Return TransactionManager
End Sub

'Resests the internal nonce counter. The current nonce value will be retrieved from the chain on the next transaction.
Public Sub ResetNonce (Credentials As W3Credentials, ChainId As Long)
	GetTransactionManager(Credentials, ChainId).As(JavaObject).RunMethod("setNonce", Array(mUtils.BigIntToNative(mUtils.BigIntFromUnit("-1", "wei"))))
End Sub





'Asynchronously returns the current block number. Result.Value type is BigInteger.
Public Sub EthBlockNumber As ResumableSub
	Dim sf As Object = SendRequest("ethBlockNumber", Null)
	Wait For (sf)RunAsync_Complete (Success As Boolean, BlockNumber As Object)
	Return mUtils.CreateW3AsyncResult(Success, IIf(Success, mUtils.BigIntFromNative(BlockNumber.As(JavaObject).RunMethod("getBlockNumber", Null)), Null), LastException)
End Sub

'Asynchronously returns the account balance. Result.Value type is BigInteger (wei units).
'BlockParameter - One of the Utils.BLOCK constants.
Public Sub EthGetBalance (Address As String, BlockParameter As Object) As ResumableSub
	Dim sf As Object = SendRequest("ethGetBalance", Array(Address, BlockParameterToDefault(BlockParameter)))
	Wait For (sf) RunAsync_Complete (Success As Boolean, GetBalance As Object)
	Return mUtils.CreateW3AsyncResult(Success, IIf(Success, mUtils.BigIntFromNative(GetBalance.As(JavaObject).RunMethod("getBalance", Null)), Null), LastException)
End Sub

'Asynchronously returns the current gas price. Result.Value type is BigInteger (wei units).
Public Sub EthGetGasPrice As ResumableSub
	Dim sf As Object = SendRequest("ethGasPrice", Null)
	Wait For (sf) RunAsync_Complete (Success As Boolean, EthGasPrice As Object)
	Return mUtils.CreateW3AsyncResult(Success, IIf(Success, mUtils.BigIntFromNative(EthGasPrice.As(JavaObject).RunMethod("getGasPrice", Null)), Null), LastException)
End Sub

'Asynchronously resolves an ENS name to an address. Result.Value type is String.
Public Sub EnsResolve(EnsName As String) As ResumableSub
	Dim sf As Object = RunAsync(EnsResolver, "resolve", Array(EnsName))
	Wait For (sf) RunAsync_Complete (Success As Boolean, o As Object)
	Return mUtils.CreateW3AsyncResult(Success, IIf(Success, o.As(String), ""), LastException)
End Sub
'Asynchronously resolves the ENS name of the provided address. Result.Value type is String.
Public Sub EnsReverseResolve(Address As String) As ResumableSub
	Dim sf As Object = RunAsync(EnsResolver, "reverseResolve", Array(Address))
	Wait For (sf) RunAsync_Complete (Success As Boolean, o As Object)
	Return mUtils.CreateW3AsyncResult(Success, IIf(Success, o.As(String), ""), LastException)
End Sub

Private Sub BlockParameterToDefault(BlockParameter As Object) As Object
	If BlockParameter Is BigInteger Then
		Dim jo As JavaObject
		jo.InitializeStatic("org.web3j.protocol.core.DefaultBlockParameter")
		Return jo.RunMethod("valueOf", Array(mUtils.BigIntToNative(BlockParameter)))
	Else
		Return BlockParameter
	End If
End Sub

'Asynchronously sends funds. Based on EIP 1559. Result.Value type is W3TransactionHash.
'ChainId - Chain id. Ethereum Mainnet id is 1.
'Credentials - Paying account credentials.
'ToAddress - Destination address.
'Amount - Value transferred in wei. You can use utils.BigIntFromUnit.
'MaxPriorityFeePerGas - The maximum fee per gas to give miners to incentivize them to include the transaction.
'MaxFeePerGas - The maximum fee per gas that the transaction is willing to pay in total.
Public Sub SendFunds (ChainId As Long, Credentials As W3Credentials, ToAddress As String, Amount As BigInteger, MaxPriorityFeePerGas As BigInteger, MaxFeePerGas As BigInteger) As ResumableSub
	Do While SendFundsLock = True
		Log("waiting")
		Sleep(100)
		
	Loop
	SendFundsLock = True
	Dim res As W3AsyncResult
	Try
		Wait For (EthGetTransactionCount(Credentials.Address, mUtils.BLOCK_PENDING)) Complete (result As W3AsyncResult)
		If result.Success = False Then
			res = mUtils.CreateW3AsyncResult(False, Null, LastException)
		Else
			Dim nonce As BigInteger = result.Value
			Wait For (SendFunds2(nonce, ChainId, Credentials, ToAddress, Amount, MaxPriorityFeePerGas, MaxFeePerGas)) Complete (result As W3AsyncResult)
			res = result
		End If
	Catch
		Log(LastException)
		res = mUtils.CreateW3AsyncResult(False, Null, LastException)
	End Try
	SendFundsLock = False
	Return res
End Sub

'Asynchronously sends funds. Based on EIP 1559. Result.Value type is W3TransactionHash.
'Nonce - Transaction nonce. This can be used to replace a pending transaction, or when sending multiple transaction at once.
'ChainId - Chain id. Ethereum Mainnet id is 1.
'Credentials - Paying account credentials.
'ToAddress - Destination address.
'Amount - Value transferred in wei. You can use utils.BigIntFromUnit.
'MaxPriorityFeePerGas - The maximum fee per gas to give miners to incentivize them to include the transaction.
'MaxFeePerGas - The maximum fee per gas that the transaction is willing to pay in total.
Public Sub SendFunds2 (Nonce As BigInteger, ChainId As Long, Credentials As W3Credentials, ToAddress As String, Amount As BigInteger, MaxPriorityFeePerGas As BigInteger, MaxFeePerGas As BigInteger) As ResumableSub
	Dim Transaction As Object = CreateTransaction(ChainId, Nonce, ToAddress, Amount, MaxPriorityFeePerGas, MaxFeePerGas, _
		mUtils.BigIntFromUnit("21000", "wei"), "")
	Dim hex As String = SignTransaction(Transaction, ChainId, Credentials)
	Wait For (EthSendRawTransaction(hex, Nonce)) Complete (Result As W3AsyncResult)
	Return Result
End Sub


Private Sub CreateTransaction(ChainId As Long, Nonce As BigInteger, ToAddress As String, Amount As BigInteger, MaxPriorityFeePerGas As BigInteger, MaxFeePerGas As BigInteger, _
		GasLimit As BigInteger, Data As String) As Object
	Dim RawTransactionClass As JavaObject
	RawTransactionClass.InitializeStatic("org.web3j.crypto.RawTransaction")
	Return RawTransactionClass.RunMethod("createTransaction", Array(ChainId, mUtils.BigIntToNative(Nonce), _
		 mUtils.BigIntToNative(GasLimit), ToAddress, mUtils.BigIntToNative(Amount), Data, mUtils.BigIntToNative(MaxPriorityFeePerGas), _
		mUtils.BigIntToNative(MaxFeePerGas)))
End Sub

'Returns BigInteger
Private Sub EthGetTransactionCount (Address As String, Block As Object) As ResumableSub
	Dim sf As Object = SendRequest("ethGetTransactionCount", Array(Address, Block))
	Wait For (sf)RunAsync_Complete (Success As Boolean, Count As Object)
	Return mUtils.CreateW3AsyncResult(Success, IIf(Success, mUtils.BigIntFromNative(Count.As(JavaObject).RunMethod("getTransactionCount", Null)) _
		, Null), LastException)
End Sub

'Returns hex string
Private Sub SignTransaction(Transaction As Object, ChainId As Long, Credentials As W3Credentials) As String
	Dim TransactionEncoder As JavaObject
	TransactionEncoder.InitializeStatic("org.web3j.crypto.TransactionEncoder")
	Return "0x" & bc.HexFromBytes(TransactionEncoder.RunMethod("signMessage", Array(Transaction, ChainId, Credentials.Native)))
End Sub

Private Sub EthSendRawTransaction(HexMessage As String, Nonce As BigInteger) As ResumableSub
	Dim sf As Object = SendRequest("ethSendRawTransaction", Array(HexMessage))
	Wait For (sf) RunAsync_Complete (Success As Boolean, EthSendTransaction As Object)
	If Success Then
		Dim th As W3TransactionHash
		th.Initialize
		Dim hash As Object = EthSendTransaction.As(JavaObject).RunMethod("getTransactionHash", Null)
		If hash <> Null Then
			th.Hash = hash
			th.Nonce = Nonce
			Return mUtils.CreateW3AsyncResult(True, th, Null)
		Else
			Log("Error sending transaction. Empty hash returned")
		End If
	End If
	Return mUtils.CreateW3AsyncResult(False, Null, LastException)
End Sub



'Returns the transaction receipt. This method will poll the node until the receipt is available or the timeout reached. Value type is W3TransactionReceipt.
'Make sure to check the Pending and StatusOk values.
'TransactionHash - Transaction hash. Only the address is used. Nonce not important.
'TimeoutMs - Polling timeout in seconds. Pass 0 for a single call. It can take several minutes (or more) for the transaction to complete.
Public Sub EthGetTransactionReceipt (TransactionHash As W3TransactionHash, TimeoutSeconds As Long) As ResumableSub
	Dim Start As Long = DateTime.Now + 10
	Do While DateTime.Now < Start + TimeoutSeconds * 1000
		Dim sf As Object = SendRequest("ethGetTransactionReceipt", Array(TransactionHash.Hash))
		Wait For (sf)RunAsync_Complete (Success As Boolean, OptionalReceipt As Object)
		If Success Then
			Dim native As Object = OptionalReceipt.As(JavaObject).RunMethodJO("getTransactionReceipt", Null).RunMethod("orElse", Array(Null))
			If native <> Null Then 
				Dim receipt As W3TransactionReceipt = TransactionFromNative(native)
				Return mUtils.CreateW3AsyncResult(True, receipt, Null)
			End If
		Else
			Return mUtils.CreateW3AsyncResult(False, Null, LastException)
		End If
		Sleep(PollingDuration)
	Loop
	Dim res As W3TransactionReceipt
	res.Initialize
	res.Pending = True
	Return mUtils.CreateW3AsyncResult(True, res, LastException)
End Sub

Private Sub TransactionFromNative(Trans As JavaObject) As W3TransactionReceipt
	Dim tw As W3TransactionReceipt
	tw.Initialize
	tw.TransactionHash = Trans.RunMethod("getTransactionHash", Null)
	tw.TransactionIndex = mUtils.BigIntFromNative(Trans.RunMethod("getTransactionIndex", Null))
	tw.BlockHash = Trans.RunMethod("getBlockHash", Null)
	tw.BlockNumber = mUtils.BigIntFromNative(Trans.RunMethod("getBlockNumber", Null))
	tw.CumulativeGasUsed = mUtils.BigIntFromNative(Trans.RunMethod("getCumulativeGasUsed", Null))
	tw.GasUsed = mUtils.BigIntFromNative(Trans.RunMethod("getGasUsed", Null))
	tw.ContractAddress = Trans.RunMethod("getContractAddress", Null)
	tw.Root = Trans.RunMethod("getRoot", Null)
	tw.StatusOk = Trans.RunMethod("isStatusOK", Null)
	tw.FromAddress = Trans.RunMethod("getFrom", Null)
	tw.ToAddress = Trans.RunMethod("getTo", Null)
'	tw.LogsBloom = Trans.RunMethod("getLogsBloom", Null)
	tw.RevertReason = Trans.RunMethod("getRevertReason", Null)
	
	tw.Logs = Trans.RunMethod("getLogs", Null)
	Dim numeric As JavaObject
	numeric.InitializeStatic("org.web3j.utils.Numeric")
	tw.EffectiveGasPrice = mUtils.BigIntFromNative(numeric.RunMethod("decodeQuantity", Array(Trans.RunMethod("getEffectiveGasPrice", Null))))
	tw.TransactionType = Trans.RunMethod("getType", Null)
	Return tw
End Sub



Private Sub SendRequest(Method As String, Params() As Object) As Object
	Return jMe.RunMethod("sendRequest", Array(Me, w3.RunMethod(Method, Params)))
End Sub

Private Sub RunAsync(Target As Object, Method As String, Params() As Object) As Object
	Dim m As JavaObject = mUtils 'ignore
	Return m.RunMethod("runAsync", Array(Me, Target, Method, Params))
End Sub



#if java
import anywheresoftware.b4j.object.JavaObject;
import java.util.concurrent.Callable;
import java.util.ArrayList;
import java.util.List;
import org.web3j.protocol.core.*;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.DefaultBlockParameter;
import org.web3j.protocol.core.methods.response.EthCall;
import org.web3j.protocol.core.methods.response.EthGetCode;
import org.web3j.protocol.core.methods.response.EthSendTransaction;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.protocol.exceptions.TransactionException;
import org.web3j.tx.exceptions.ContractCallException;
import org.web3j.tx.response.PollingTransactionReceiptProcessor;
import org.web3j.tx.response.TransactionReceiptProcessor;
import java.io.IOException;
import org.web3j.crypto.Credentials;
import java.math.BigInteger;

public Object sendRequest (B4AClass instance, final Request request){
	Object sender = new Object();
	BA.runAsync(instance.getBA(), sender, "runasync_complete", new Object[] {false, null}, 
		new Callable<Object[]>() {
			public Object[] call() throws Exception {
				return new Object[] {true, request.send()};
			}
		}
	);
	return sender;
}
public static class MyTransactionManager extends org.web3j.tx.FastRawTransactionManager {
	public MyTransactionManager(Web3j web3j, Credentials credentials) {
		super(web3j, credentials);
	}
  @Override
  public TransactionReceipt executeTransactionEIP1559(
            long chainId,
            BigInteger maxPriorityFeePerGas,
            BigInteger maxFeePerGas,
            BigInteger gasLimit,
            String to,
            String data,
            BigInteger value)
            throws IOException, TransactionException {
        return executeTransactionEIP1559(
                chainId, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, data, value, false);
    }
}
 

      
#end if