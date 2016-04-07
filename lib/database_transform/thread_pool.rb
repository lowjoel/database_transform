class DatabaseTransform::ThreadPool
  # Special job to stop the thread.
  STOP = :stop

  def initialize(size)
    @size = size
    @jobs = Queue.new

    @workers = (1..@size).map do
      thread = Thread.new do
        loop do
          job = @jobs.pop
          break if job == STOP

          execute_job(job)
        end
      end

      thread.abort_on_exception = true
      thread
    end
  end

  def schedule(&job)
    @jobs << job
  end

  # Wait for all jobs to finish.
  def wait
    @size.times do
      @jobs << STOP
    end

    @workers.each(&:join)
  end

  private

  def execute_job(job)
    if @around_job_proc
      @around_job_proc.call(job)
    else
      job.call
    end
  end
end
