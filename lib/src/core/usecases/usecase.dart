abstract interface class UseCase<Result, Params> {
  Result call(Params params);
}

class NoParams {
  const NoParams();
}
