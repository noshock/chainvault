import { useState, useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'

import {
  useAccount,
  useBalance,
  useReadContract,
  useConnect,
} from 'wagmi'
import { formatEther, formatUnits } from 'viem'
import {
  CHAINVAULT_ADDRESS,
  CVT_TOKEN_ADDRESS,
  CHAINVAULT_ABI,
  ERC20_ABI,
} from './contracts'

import {
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi'

import { parseEther, parseUnits } from 'viem'

function App() {
    const queryClient = useQueryClient()

    const refreshBalances = () => {
      queryClient.invalidateQueries({
        queryKey: ['readContract'],
      })
    }

  const { address, isConnected, chain } = useAccount()
  const [ethAmount, setEthAmount] = useState('')
  const [cvtApprovalAmount, setCvtApprovalAmount] = useState('')
  const [cvtDepositAmount, setCvtDepositAmount] = useState('')
  const [cvtWithdrawAmount, setCvtWithdrawAmount] = useState('')
  const { connect, connectors, isPending, error } = useConnect()

  const {
    writeContract: withdrawToken,
    data: tokenWithdrawHash,
    isPending: isTokenWithdrawing,
    error: tokenWithdrawError,
  } = useWriteContract()

  const {
    isLoading: isTokenWithdrawConfirming,
    isSuccess: tokenWithdrawSuccess,
  } = useWaitForTransactionReceipt({
    hash: tokenWithdrawHash,
  })

  const {
    writeContract: approveToken,
    data: approvalHash,
    isPending: isApproving,
    error: approvalError,
  } = useWriteContract()

  const {
    writeContract: depositToken,
    data: tokenDepositHash,
    isPending: isTokenDepositing,
    error: tokenDepositError,
  } = useWriteContract()

  const {
    isLoading: isTokenDepositConfirming,
    isSuccess: tokenDepositSuccess,
  } = useWaitForTransactionReceipt({
    hash: tokenDepositHash,
  })

  const {
    isLoading: isApprovalConfirming,
    isSuccess: approvalSuccess,
  } = useWaitForTransactionReceipt({
    hash: approvalHash,
  })
  const [withdrawAmount, setWithdrawAmount] = useState('')

  const {
    writeContract: withdrawETH,
    data: withdrawHash,
    isPending: isWithdrawing,
    error: withdrawError,
  } = useWriteContract()

  const {
    isLoading: isWithdrawConfirming,
    isSuccess: withdrawSuccess,
  } = useWaitForTransactionReceipt({
    hash: withdrawHash,
  })

  const {
    writeContract,
    data: depositHash,
    isPending: isDepositing,
    error: depositError,
  } = useWriteContract()

  const {
    isLoading: isConfirming,
    isSuccess: depositSuccess,
  } = useWaitForTransactionReceipt({
    hash: depositHash,
  })

    useEffect(() => {
    if (
      depositSuccess ||
      withdrawSuccess ||
      tokenDepositSuccess ||
      tokenWithdrawSuccess
    ) {
      refreshBalances()
    }
  }, [
    depositSuccess,
    withdrawSuccess,
    tokenDepositSuccess,
    tokenWithdrawSuccess,
  ])

  function handleEthDeposit() {
    if (!ethAmount || Number(ethAmount) <= 0) {
      return
    }

    if (chain?.id !== 11155111) {
      alert('Please switch to Sepolia network')
      return
    }

    writeContract({
      address: CHAINVAULT_ADDRESS,
      abi: CHAINVAULT_ABI,
      functionName: 'depositETH',
      value: parseEther(ethAmount),
    })
  }

  function handleCvtApproval() {
    if (!cvtApprovalAmount || Number(cvtApprovalAmount) <= 0) {
      return
    }

    if (chain?.id !== 11155111) {
      alert('Please switch to Sepolia network')
      return
    }

    approveToken({
      address: CVT_TOKEN_ADDRESS,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [
        CHAINVAULT_ADDRESS,
        parseUnits(cvtDepositAmount, 18),
      ],
    })
  }

  function handleCvtDeposit() {
    if (!cvtDepositAmount || Number(cvtDepositAmount) <= 0) {
      return
    }

    if (chain?.id !== 11155111) {
      alert('Please switch to Sepolia network')
      return
    }

    depositToken({
      address: CHAINVAULT_ADDRESS,
      abi: CHAINVAULT_ABI,
      functionName: 'depositToken',
      args: [
        CVT_TOKEN_ADDRESS,
        parseUnits(cvtDepositAmount, 18),
      ],
    })
  }

  function handleCvtWithdraw() {
    if (!cvtWithdrawAmount || Number(cvtWithdrawAmount) <= 0) {
      return
    }

    if (chain?.id !== 11155111) {
      alert('Please switch to Sepolia network')
      return
    }

    if (!isOwner) {
      alert('Only the vault owner can withdraw')
      return
    }

    withdrawToken({
      address: CHAINVAULT_ADDRESS,
      abi: CHAINVAULT_ABI,
      functionName: 'withdrawToken',
      args: [
        CVT_TOKEN_ADDRESS,
        parseUnits(cvtWithdrawAmount, 18),
      ],
    })
  }

  function handleEthWithdraw() {
    if (!withdrawAmount || Number(withdrawAmount) <= 0) {
      alert('Enter a valid withdrawal amount')
      return
    }

    if (chain?.id !== 11155111) {
      alert('Please switch to Sepolia network')
      return
    }

    if (!isOwner) {
      alert('Only the vault owner can withdraw')
      return
    }

    withdrawETH({
      address: CHAINVAULT_ADDRESS,
      abi: CHAINVAULT_ABI,
      functionName: 'withdrawETH',
      args: [parseEther(withdrawAmount)],
    })
  }

  const { data: walletEth } = useBalance({
    address,
    query: { enabled: !!address },
  })

  const { data: vaultOwner } = useReadContract({
    address: CHAINVAULT_ADDRESS,
    abi: CHAINVAULT_ABI,
    functionName: 'owner',
  })

  const { data: vaultEth } = useReadContract({
    address: CHAINVAULT_ADDRESS,
    abi: CHAINVAULT_ABI,
    functionName: 'ethBalance',
  })

  const { data: walletCvt } = useReadContract({
    address: CVT_TOKEN_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address!],
    query: { enabled: !!address },
  })

  const { data: vaultCvt } = useReadContract({
    address: CHAINVAULT_ADDRESS,
    abi: CHAINVAULT_ABI,
    functionName: 'tokenBalance',
    args: [CVT_TOKEN_ADDRESS],
  })

  const { data: tokenAllowed } = useReadContract({
    address: CHAINVAULT_ADDRESS,
    abi: CHAINVAULT_ABI,
    functionName: 'allowedTokens',
    args: [CVT_TOKEN_ADDRESS],
  })

  const isOwner =
    !!address &&
    !!vaultOwner &&
    address.toLowerCase() === vaultOwner.toLowerCase()

 if (!isConnected) {
  return (
    <main className="min-h-screen bg-slate-950 text-white flex items-center justify-center">
      <div className="rounded-2xl bg-slate-900 p-8 text-center">
        <h1 className="text-3xl font-bold">ChainVault</h1>

        <p className="mt-3 text-slate-400">
          Connect your wallet to view your vault.
        </p>

        <button
          onClick={() => connect({ connector: connectors[0] })}
          disabled={isPending || !connectors[0]}
          className="mt-6 rounded-lg bg-blue-600 px-6 py-3 font-semibold hover:bg-blue-500 disabled:opacity-50"
        >
          {isPending ? 'Connecting...' : 'Connect MetaMask'}
        </button>

        {error && (
          <p className="mt-4 text-sm text-red-400">
            {error.message}
          </p>
        )}
      </div>
    </main>
  )
}



  return (
    <main className="min-h-screen bg-slate-950 p-6 text-white">
      <div className="mx-auto max-w-5xl">
        <header className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <h1 className="text-3xl font-bold">ChainVault</h1>
            <p className="mt-1 text-slate-400">
              Personal crypto vault · Sepolia
            </p>
          </div>

          <div className="rounded-xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm">
            {address?.slice(0, 6)}...{address?.slice(-4)}
          </div>
        </header>

        {chain?.id !== 11155111 && (
          <div className="mt-6 rounded-xl border border-amber-700 bg-amber-950 p-4 text-amber-300">
            Please switch MetaMask to the Sepolia network.
          </div>
        )}

        <section className="mt-8 grid gap-5 md:grid-cols-2">
          <BalanceCard
            title="Wallet ETH"
            value={walletEth ? `${Number(formatEther(walletEth.value)).toFixed(5)} ETH` : 'Loading...'}
          />

          <BalanceCard
            title="Vault ETH"
            value={vaultEth !== undefined ? `${Number(formatEther(vaultEth)).toFixed(5)} ETH` : 'Loading...'}
          />

          <BalanceCard
            title="Wallet CVT"
            value={walletCvt !== undefined ? `${Number(formatUnits(walletCvt, 18)).toFixed(2)} CVT` : 'Loading...'}
          />

          <BalanceCard
            title="Vault CVT"
            value={vaultCvt !== undefined ? `${Number(formatUnits(vaultCvt, 18)).toFixed(2)} CVT` : 'Loading...'}
          />
        </section>


        <section className="mt-6 rounded-2xl border border-slate-800 bg-slate-900 p-6">
          <h2 className="text-xl font-semibold">Deposit ETH</h2>

          <input
            type="number"
            min="0"
            step="0.001"
            placeholder="Enter ETH amount"
            value={ethAmount}
            onChange={(e) => setEthAmount(e.target.value)}
            className="mt-4 w-full rounded-xl border border-slate-700 bg-slate-800 p-3 text-white"
          />

          <button
            onClick={handleEthDeposit}
            disabled={isDepositing || isConfirming || chain?.id !== 11155111}
            className="mt-4 w-full rounded-xl bg-indigo-600 p-3 font-semibold hover:bg-indigo-700 disabled:opacity-50"
          >
            {isDepositing
              ? 'Confirm in wallet...'
              : isConfirming
                ? 'Confirming transaction...'
                : 'Deposit ETH'}
          </button>

          {depositSuccess && (
            <p className="mt-3 text-green-400">
              ETH deposit successful!
            </p>
          )}

          {depositError && (
            <p className="mt-3 break-words text-red-400">
              {depositError.message}
            </p>
          )}
        </section>


        <section className="mt-6 rounded-2xl border border-slate-800 bg-slate-900 p-6">
          <h2 className="text-xl font-semibold">Withdraw ETH</h2>

          <input
            type="number"
            min="0"
            step="0.001"
            placeholder="Enter ETH amount"
            value={withdrawAmount}
            onChange={(e) => setWithdrawAmount(e.target.value)}
            disabled={!isOwner}
            className="mt-4 w-full rounded-xl border border-slate-700 bg-slate-800 p-3 text-white disabled:opacity-50"
          />

          <button
            onClick={handleEthWithdraw}
            disabled={
              !isOwner ||
              isWithdrawing ||
              isWithdrawConfirming ||
              chain?.id !== 11155111
            }
            className="mt-4 w-full rounded-xl bg-red-600 p-3 font-semibold hover:bg-red-700 disabled:opacity-50"
          >
            {isWithdrawing
              ? 'Confirm in wallet...'
              : isWithdrawConfirming
                ? 'Confirming transaction...'
                : 'Withdraw ETH'}
          </button>

          {!isOwner && (
            <p className="mt-3 text-amber-400">
              Only the vault owner can withdraw ETH.
            </p>
          )}

          {withdrawSuccess && (
            <p className="mt-3 text-green-400">
              ETH withdrawal successful!
            </p>
          )}

          {withdrawError && (
            <p className="mt-3 break-words text-red-400">
              {withdrawError.message}
            </p>
          )}
        </section>


        <section className="mt-6 rounded-2xl border border-slate-800 bg-slate-900 p-6">
          <h2 className="text-xl font-semibold">CVT Token Approval</h2>

          <input
            type="number"
            min="0"
            step="1"
            placeholder="Enter CVT amount"
            value={cvtApprovalAmount}
            onChange={(e) => setCvtApprovalAmount(e.target.value)}
            className="mt-4 w-full rounded-xl border border-slate-700 bg-slate-800 p-3 text-white"
          />

          <button
            onClick={handleCvtApproval}
            disabled={
              isApproving ||
              isApprovalConfirming ||
              chain?.id !== 11155111
            }
            className="mt-4 w-full rounded-xl bg-indigo-600 p-3 font-semibold hover:bg-indigo-700 disabled:opacity-50"
          >
            {isApproving
              ? 'Confirm in wallet...'
              : isApprovalConfirming
                ? 'Confirming approval...'
                : 'Approve CVT'}
          </button>

          {approvalSuccess && (
            <p className="mt-3 text-green-400">
              CVT approval successful!
            </p>
          )}

          {approvalError && (
            <p className="mt-3 break-words text-red-400">
              {approvalError.message}
            </p>
          )}
        </section>


        <section className="mt-6 rounded-2xl border border-slate-800 bg-slate-900 p-6">
          <h2 className="text-xl font-semibold">Deposit CVT</h2>

          <p className="mt-2 text-sm text-slate-400">
            Approve CVT first, then deposit your tokens.
          </p>

          <input
            type="number"
            min="0"
            step="any"
            placeholder="Enter CVT amount to deposit"
            value={cvtDepositAmount}
            onChange={(e) => setCvtDepositAmount(e.target.value)}
            className="w-full rounded-xl border border-slate-600 bg-slate-800 p-3 text-white"
          />

          <button
            onClick={handleCvtDeposit}
            disabled={
              isTokenDepositing ||
              isTokenDepositConfirming ||
              chain?.id !== 11155111
            }
            className="mt-4 w-full rounded-xl bg-indigo-600 p-3 font-semibold hover:bg-indigo-700 disabled:opacity-50"
          >
            {isTokenDepositing
              ? 'Confirm in wallet...'
              : isTokenDepositConfirming
                ? 'Confirming deposit...'
                : 'Deposit CVT'}
          </button>

          {tokenDepositSuccess && (
            <p className="mt-3 text-green-400">
              CVT deposit successful!
            </p>
          )}

          {tokenDepositError && (
            <p className="mt-3 break-words text-red-400">
              {tokenDepositError.message}
            </p>
          )}
        </section>


        <section className="mt-6 rounded-2xl border border-slate-800 bg-slate-900 p-6">
          <h2 className="text-xl font-semibold">Withdraw CVT</h2>

          <input
            type="number"
            min="0"
            step="1"
            placeholder="Enter CVT amount"
            value={cvtWithdrawAmount}
            onChange={(e) => setCvtWithdrawAmount(e.target.value)}
            disabled={!isOwner}
            className="mt-4 w-full rounded-xl border border-slate-700 bg-slate-800 p-3 text-white disabled:opacity-50"
          />

          <button
            onClick={handleCvtWithdraw}
            disabled={
              !isOwner ||
              isTokenWithdrawing ||
              isTokenWithdrawConfirming ||
              chain?.id !== 11155111
            }
            className="mt-4 w-full rounded-xl bg-red-600 p-3 font-semibold hover:bg-red-700 disabled:opacity-50"
          >
            {isTokenWithdrawing
              ? 'Confirm in wallet...'
              : isTokenWithdrawConfirming
                ? 'Confirming withdrawal...'
                : 'Withdraw CVT'}
          </button>

          {!isOwner && (
            <p className="mt-3 text-amber-400">
              Only the vault owner can withdraw CVT.
            </p>
          )}

          {tokenWithdrawSuccess && (
            <p className="mt-3 text-green-400">
              CVT withdrawal successful!
            </p>
          )}

          {tokenWithdrawError && (
            <p className="mt-3 break-words text-red-400">
              {tokenWithdrawError.message}
            </p>
          )}
        </section>

        <section className="mt-6 rounded-2xl border border-slate-800 bg-slate-900 p-6">
          <h2 className="text-xl font-semibold">Vault information</h2>

          <div className="mt-5 space-y-3 text-sm">
            <p>
              <span className="text-slate-400">Network:</span> Sepolia
            </p>
            <p>
              <span className="text-slate-400">Token:</span> ChainVault Test Token (CVT)
            </p>
            <p>
              <span className="text-slate-400">CVT allowlisted:</span>{' '}
              {tokenAllowed === undefined ? 'Loading...' : tokenAllowed ? 'Yes' : 'No'}
            </p>
            <p>
              <span className="text-slate-400">Connected wallet role:</span>{' '}
              {isOwner ? 'Vault Owner' : 'Visitor'}
            </p>
            <p className="break-all">
              <span className="text-slate-400">Vault address:</span>{' '}
              {CHAINVAULT_ADDRESS}
            </p>
          </div>
        </section>

        <div className="mt-6 rounded-xl border border-amber-800 bg-amber-950 p-4 text-sm text-amber-200">
          <strong>Important:</strong> Deposits are controlled by the vault
          owner. Individual depositors cannot independently withdraw or
          recover their deposits. Only the current owner can withdraw funds.
          Use testnet assets only.
        </div>
      </div>
    </main>
  )
}

function BalanceCard({
  title,
  value,
}: {
  title: string
  value: string
}) {
  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900 p-6">
      <p className="text-sm text-slate-400">{title}</p>
      <p className="mt-3 text-2xl font-bold">{value}</p>
    </div>
  )
}

export default App
